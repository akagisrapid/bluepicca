import Foundation
import Security

// Global SessionManager class that can be accessed from anywhere in the app
class SessionManager {
  static let shared = SessionManager()

  private var currentSession: CreateSessionResponse?
  private var lastSessionTime: Date?
  private let sessionExpiryTime: TimeInterval = 12 * 60 * 60  // 12 hours in seconds
  private var ongoingSessionTask: Task<CreateSessionResponse, Error>?

  private let userDefaults = UserDefaults.standard
  private let lastSessionTimeKey = "bsky_last_session_time"

  private let keychainService = "com.bskyapp.credentials"
  private let keychainIdentifierAccount = "bsky_identifier"
  private let keychainPasswordAccount = "bsky_app_password"

  private init() {
    // Load last session time from UserDefaults if available
    if let lastTime = userDefaults.object(forKey: lastSessionTimeKey) as? Date {
      lastSessionTime = lastTime
    }
    // Migrate credentials from UserDefaults to Keychain if they exist
    migrateCredentialsFromUserDefaults()
    migrateKeychainAccessibility()
  }

  func getSession() async throws -> CreateSessionResponse {
    // アクセストークンは 2 時間で切れる（PDS の既定）。12 時間の sessionExpiryTime で使い回すと、
    // アプリを開いたまま 2 時間を過ぎたところで全 API が ExpiredToken で失敗する
    // ponytail: 切れたらアプリパスワードで createSession し直す（1 日十数回で上限 300 回/日には届かない）。増えるなら refreshJwt で refreshSession にする
    if let session = currentSession, Self.isAccessTokenValid(session.accessJwt) {
      return session
    }

    // 既存のセッション作成タスクがあればそれを待つ（並行リクエストによる多重ログインを防ぐ）
    if let existing = ongoingSessionTask {
      return try await existing.value
    }

    // Check if we have saved credentials
    guard let identifier = getSavedIdentifier(), let password = getSavedAppPassword() else {
      throw SessionError.noSavedCredentials
    }

    let task = Task<CreateSessionResponse, Error> {
      defer {
        Task { @MainActor in self.ongoingSessionTask = nil }
      }
      let newSession = try await createSession(identifier: identifier, password: password)
      await MainActor.run {
        self.currentSession = newSession
        self.lastSessionTime = Date()
        self.userDefaults.set(self.lastSessionTime, forKey: self.lastSessionTimeKey)
      }
      return newSession
    }
    ongoingSessionTask = task
    return try await task.value
  }

  func createSessionWithCredentials(identifier: String, password: String) async throws
    -> CreateSessionResponse
  {
    // Create a new session with provided credentials
    let newSession = try await createSession(identifier: identifier, password: password)

    // Save credentials
    saveCredentials(identifier: identifier, password: password)

    // Update session properties on the main thread
    await MainActor.run {
      currentSession = newSession
      lastSessionTime = Date()
      userDefaults.set(lastSessionTime, forKey: lastSessionTimeKey)
    }

    return newSession
  }

  func clearSession() {
    // Ensure we're on the main thread when updating properties
    DispatchQueue.main.async {
      self.currentSession = nil
      self.lastSessionTime = nil
      self.userDefaults.removeObject(forKey: self.lastSessionTimeKey)
    }
  }

  func logout() {
    clearSession()
    clearSavedCredentials()
  }

  var currentDid: String? { currentSession?.did }

  /// JWT の exp を読み、1 分以上の余裕があれば有効とみなす。読めないトークンは無効として取り直す
  static func isAccessTokenValid(_ jwt: String, now: Date = Date()) -> Bool {
    let parts = jwt.split(separator: ".")
    guard parts.count == 3 else { return false }
    var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64),
      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let exp = payload["exp"] as? Double
    else { return false }
    return Date(timeIntervalSince1970: exp).timeIntervalSince(now) > 60
  }

  func isLoggedIn() -> Bool {
    if currentSession != nil && lastSessionTime != nil
      && Date().timeIntervalSince(lastSessionTime!) < sessionExpiryTime
    {
      return true
    }

    // If we have saved credentials, we can try to create a new session
    if getSavedIdentifier() != nil && getSavedAppPassword() != nil {
      // We have saved credentials, but we need to check if the last session time is valid
      if let lastTime = lastSessionTime,
        Date().timeIntervalSince(lastTime) < sessionExpiryTime
      {
        return true
      }
    }

    return false
  }

  // MARK: - Keychain Methods

  private func saveCredentials(identifier: String, password: String) {
    saveToKeychain(account: keychainIdentifierAccount, value: identifier)
    saveToKeychain(account: keychainPasswordAccount, value: password)
  }

  private func getSavedIdentifier() -> String? {
    return readFromKeychain(account: keychainIdentifierAccount)
  }

  private func getSavedAppPassword() -> String? {
    return readFromKeychain(account: keychainPasswordAccount)
  }

  private func clearSavedCredentials() {
    deleteFromKeychain(account: keychainIdentifierAccount)
    deleteFromKeychain(account: keychainPasswordAccount)
  }

  private func saveToKeychain(account: String, value: String) {
    guard let data = value.data(using: .utf8) else { return }

    // Delete existing item first
    deleteFromKeychain(account: account)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      // 通知のバックグラウンド確認は画面ロック中にも走るので、初回ロック解除後は読めるようにする
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]

    SecItemAdd(query as CFDictionary, nil)
  }

  private func readFromKeychain(account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess, let data = result as? Data else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  private func deleteFromKeychain(account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
    ]

    SecItemDelete(query as CFDictionary)
  }

  // MARK: - Migration

  /// 以前の既定（ロック解除中のみ読める）で保存した資格情報を、ロック中も読めるように付け替える
  private func migrateKeychainAccessibility() {
    for account in [keychainIdentifierAccount, keychainPasswordAccount] {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: account,
      ]
      let attributes: [String: Any] = [
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
      ]
      SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }
  }

  private func migrateCredentialsFromUserDefaults() {
    let oldIdentifierKey = "bsky_identifier"
    let oldPasswordKey = "bsky_app_password"

    if let identifier = userDefaults.string(forKey: oldIdentifierKey) {
      saveToKeychain(account: keychainIdentifierAccount, value: identifier)
      userDefaults.removeObject(forKey: oldIdentifierKey)
    }
    if let password = userDefaults.string(forKey: oldPasswordKey) {
      saveToKeychain(account: keychainPasswordAccount, value: password)
      userDefaults.removeObject(forKey: oldPasswordKey)
    }
  }
}

// Error types for SessionManager
enum SessionError: Error {
  case noSavedCredentials
  case invalidCredentials
  case networkError
  case unknown
}
