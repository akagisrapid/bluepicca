import Foundation
import UIKit

/// プッシュ通知の中継サーバー（リポジトリの server/）の接続先
enum PushServerConfig {
  /// 例: "https://push.example.com"。空のあいだはプッシュを使わず、端末内の定期確認だけで通知する
  static let baseURL = "https://bluepicca-push.duckdns.org"
  /// サーバーの環境変数 SERVICE_DID と同じ値（例: "did:web:push.example.com"）
  static let serviceDid = "did:web:bluepicca-push.duckdns.org"

  static var isConfigured: Bool { !baseURL.isEmpty && !serviceDid.isEmpty }
}

/// APNs の端末トークンと通知設定を中継サーバーに登録する。
/// 本人確認には PDS の com.atproto.server.getServiceAuth で発行した短命の JWT を使うので、
/// アプリパスワードやアクセストークンはサーバーに渡さない
final class PushRegistrationService {
  static let shared = PushRegistrationService()

  private let registerMethod = "lapipearpopo.bskyapp.push.register"
  private let unregisterMethod = "lapipearpopo.bskyapp.push.unregister"
  private let defaults = UserDefaults.standard
  private let deviceTokenKey = "pushDeviceToken"
  private let lastRegisteredBodyKey = "pushLastRegisteredBody"
  private let lastRegisteredAtKey = "pushLastRegisteredAt"
  private let lastErrorKey = "pushLastError"
  /// 内容が変わらなくても、サーバー側で消えていたときのためにこの間隔で登録し直す
  private let reregisterInterval: TimeInterval = 24 * 60 * 60

  #if DEBUG
    private let environment = "sandbox"
  #else
    private let environment = "production"
  #endif

  private init() {}

  /// サーバーに登録済みで、通知がプッシュで届く状態か。端末内の定期確認と二重に出さないために見る
  var isActive: Bool {
    PushServerConfig.isConfigured && NotificationSettings.shared.isEnabled
      && defaults.data(forKey: lastRegisteredBodyKey) != nil
  }

  /// 設定画面に出す登録状態。TestFlight では Xcode のログが見られないので、ここで確かめる
  var statusText: String? {
    guard PushServerConfig.isConfigured, NotificationSettings.shared.isEnabled else { return nil }
    if let error = defaults.string(forKey: lastErrorKey) {
      return String(localized: "プッシュ通知の登録に失敗しました（\(error)）")
    }
    guard isActive else { return String(localized: "プッシュ通知を登録しています") }
    return environment == "production"
      ? String(localized: "プッシュ通知を登録済み（本番環境）")
      : String(localized: "プッシュ通知を登録済み（開発環境）")
  }

  /// 端末トークンの発行に失敗したとき（Push Notifications の権限がないビルドなど）
  func didFailToRegister(_ error: Error) {
    defaults.set(error.localizedDescription, forKey: lastErrorKey)
  }

  /// 端末トークンを取り直す。届いたら `didReceiveDeviceToken` から登録する。
  /// 起動時や設定を変えたときに呼ぶ（内容が変わっていなければ送らない）
  @MainActor
  func refresh() {
    guard PushServerConfig.isConfigured, NotificationSettings.shared.isEnabled else { return }
    UIApplication.shared.registerForRemoteNotifications()
  }

  func didReceiveDeviceToken(_ deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    defaults.set(token, forKey: deviceTokenKey)
    Task { await registerIfNeeded() }
  }

  private struct Registration: Encodable, Equatable {
    let token: String
    let environment: String
    let reasons: [String]
    let mutedDids: [String]
    let muteWords: [String]
  }

  func registerIfNeeded() async {
    guard PushServerConfig.isConfigured, NotificationSettings.shared.isEnabled,
      let token = defaults.string(forKey: deviceTokenKey)
    else { return }

    let registration = Registration(
      token: token,
      environment: environment,
      reasons: NotificationSettings.shared.enabledReasons.map(\.rawValue).sorted(),
      mutedDids: MutedUsersManager.shared.mutedDIDs.sorted(),
      muteWords: MuteWordManager.shared.muteWords)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let body = try? encoder.encode(registration) else { return }

    if body == defaults.data(forKey: lastRegisteredBodyKey),
      let last = defaults.object(forKey: lastRegisteredAtKey) as? Date,
      Date().timeIntervalSince(last) < reregisterInterval
    {
      // 登録は最新なので、端末トークンの発行で前に失敗していた分の表示も消す
      defaults.removeObject(forKey: lastErrorKey)
      return
    }

    do {
      try await call(registerMethod, body: body)
      defaults.set(body, forKey: lastRegisteredBodyKey)
      defaults.set(Date(), forKey: lastRegisteredAtKey)
      defaults.removeObject(forKey: lastErrorKey)
      dlog("Registered push token")
    } catch {
      defaults.set(error.localizedDescription, forKey: lastErrorKey)
      dlog("Push registration failed: \(error)")
    }
  }

  /// 通知をオフにしたときとログアウトの前に呼ぶ（ログアウト後は JWT を発行できない）
  func unregister() async {
    guard PushServerConfig.isConfigured, defaults.data(forKey: lastRegisteredBodyKey) != nil,
      let token = defaults.string(forKey: deviceTokenKey)
    else { return }
    defaults.removeObject(forKey: lastRegisteredBodyKey)
    defaults.removeObject(forKey: lastRegisteredAtKey)
    defaults.removeObject(forKey: lastErrorKey)
    do {
      try await call(unregisterMethod, body: JSONEncoder().encode(["token": token]))
    } catch {
      // 消し損ねても、アプリを消せば APNs が無効なトークンとして返すのでサーバー側で消える
      dlog("Push unregistration failed: \(error)")
    }
  }

  private struct ServiceAuthResponse: Decodable {
    let token: String
  }

  private func call(_ method: String, body: Data) async throws {
    let session = try await SessionManager.shared.getSession()
    let query: [String: Any] = [
      "aud": PushServerConfig.serviceDid,
      "lxm": method,
      "exp": Int(Date().timeIntervalSince1970) + 60,
    ]
    let auth = try await HTTPClient.decode(
      ServiceAuthResponse.self, "https://bsky.social/xrpc/com.atproto.server.getServiceAuth",
      query: query, headers: ["Authorization": "Bearer \(session.accessJwt)"])

    guard let url = URL(string: "\(PushServerConfig.baseURL)/xrpc/\(method)") else {
      throw URLError(.badURL)
    }
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
    _ = try await HTTPClient.send(request)
  }
}

/// APNs の端末トークンを受け取るためだけの AppDelegate
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    PushRegistrationService.shared.didReceiveDeviceToken(deviceToken)
  }

  func application(
    _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PushRegistrationService.shared.didFailToRegister(error)
    dlog("Failed to register for remote notifications: \(error)")
  }
}
