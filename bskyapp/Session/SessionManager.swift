import Foundation
import Security

// Global SessionManager class that can be accessed from anywhere in the app
class SessionManager {
    static let shared = SessionManager()

    private var currentSession: CreateSessionResponse?
    private var lastSessionTime: Date?
    private let sessionExpiryTime: TimeInterval = 12 * 60 * 60 // 12 hours in seconds
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
    }

    func getSession() async throws -> CreateSessionResponse {
        // If we have a valid session that's not expired, return it
        if let session = currentSession, let lastTime = lastSessionTime,
           Date().timeIntervalSince(lastTime) < sessionExpiryTime {
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
            let newSession = try await createSession(identifier: identifier, password: password)
            await MainActor.run {
                self.currentSession = newSession
                self.lastSessionTime = Date()
                self.userDefaults.set(self.lastSessionTime, forKey: self.lastSessionTimeKey)
                self.ongoingSessionTask = nil
            }
            return newSession
        }
        ongoingSessionTask = task
        return try await task.value
    }

    func createSessionWithCredentials(identifier: String, password: String) async throws -> CreateSessionResponse {
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

    func isLoggedIn() -> Bool {
        if currentSession != nil && lastSessionTime != nil &&
           Date().timeIntervalSince(lastSessionTime!) < sessionExpiryTime {
            return true
        }

        // If we have saved credentials, we can try to create a new session
        if getSavedIdentifier() != nil && getSavedAppPassword() != nil {
            // We have saved credentials, but we need to check if the last session time is valid
            if let lastTime = lastSessionTime,
               Date().timeIntervalSince(lastTime) < sessionExpiryTime {
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
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
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
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Migration

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
