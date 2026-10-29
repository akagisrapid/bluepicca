import BackgroundTasks
import Foundation
import UserNotifications

/// Bluesky の新着通知を取りに行き、設定で選んだ対象をローカル通知で知らせる。
/// Bluesky のプッシュは公式アプリの APNs にしか届かないので、サーバーを持たないこのアプリは
/// 起動中の定期確認とバックグラウンド更新（BGAppRefreshTask）でポーリングする。
/// バックグラウンド更新をいつ走らせるかは iOS が決めるため、届くまで数十分以上かかることがある
final class LocalNotificationService: NSObject, UNUserNotificationCenterDelegate {
  static let shared = LocalNotificationService()
  /// Info.plist の BGTaskSchedulerPermittedIdentifiers と揃える
  static let refreshTaskIdentifier = "lapipearpopo.bskyapp.notificationRefresh"
  /// 1 回の確認で個別に出す通知の上限。超えた分は件数だけの通知にまとめる
  static let maxNotificationsPerCheck = 5

  private let api = GetNotificationsApi()
  private let settings = NotificationSettings.shared
  private let defaults = UserDefaults.standard
  private let lastSeenKey = "pushNotificationLastSeenAt"
  private let notifiedUrisKey = "pushNotificationNotifiedUris"
  private let maxRememberedUris = 200
  private var isChecking = false

  private override init() {
    super.init()
  }

  // MARK: - 権限

  func requestAuthorization() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]))
      ?? false
  }

  func isAuthorized() async -> Bool {
    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    return status == .authorized || status == .provisional
  }

  // MARK: - 確認と配信

  /// 前回の確認以降に届いた通知のうち、設定で選んだものをローカル通知で出す
  @MainActor
  func checkForNewNotifications() async {
    guard settings.isEnabled, !isChecking else { return }
    isChecking = true
    defer { isChecking = false }
    guard await isAuthorized() else { return }

    do {
      let session = try await SessionManager.shared.getSession()
      let response = try await api.getNotifications(limit: 50)
      let newest = response.notifications.compactMap(\.indexedAtDate).max()

      guard let lastSeen = defaults.object(forKey: lastSeenKey) as? Date else {
        // 初回は基準点を置くだけにして、過去の通知をまとめて出さない
        defaults.set(newest ?? Date(), forKey: lastSeenKey)
        return
      }

      let alreadyNotified = Set(defaults.stringArray(forKey: notifiedUrisKey) ?? [])
      let items = Self.notificationsToDeliver(
        response.notifications, since: lastSeen, alreadyNotified: alreadyNotified,
        myDid: session.did, reasons: settings.enabledReasons,
        isMutedUser: { MutedUsersManager.shared.isMuted($0) },
        isMutedText: { MuteWordManager.shared.matches($0) })

      await deliver(items)

      if let newest, newest > lastSeen {
        defaults.set(newest, forKey: lastSeenKey)
      }
      remember(items.map(\.uri))
      dlog("Notification check: \(items.count) new of \(response.notifications.count)")
    } catch {
      dlog("Notification check error: \(error)")
    }
  }

  /// 通知を出す対象を選ぶ。古い順に返す
  /// - Parameters:
  ///   - since: 前回の確認で見た最新の `indexedAt`。秒単位で比べるので同じ秒のものも含め、
  ///     出し済みかどうかは `alreadyNotified`（通知の uri）で見分ける
  static func notificationsToDeliver(
    _ items: [NotificationItem], since lastSeen: Date, alreadyNotified: Set<String>,
    myDid: String, reasons: Set<NotificationReason>,
    isMutedUser: (String) -> Bool = { _ in false },
    isMutedText: (String) -> Bool = { _ in false }
  ) -> [NotificationItem] {
    items.filter { item in
      guard let reason = NotificationReason(rawValue: item.reason), reasons.contains(reason),
        !item.isRead,
        let date = item.indexedAtDate, date >= lastSeen,
        !alreadyNotified.contains(item.uri),
        item.author.did != myDid,
        !isMutedUser(item.author.did)
      else { return false }
      if let text = item.record?.text, isMutedText(text) { return false }
      // reply はスレッド内の他人宛の返信でも届くので、自分の投稿への返信だけにする
      if reason == .reply {
        guard let parentUri = item.record?.reply?.parent?.uri else { return false }
        return parentUri.hasPrefix("at://\(myDid)/")
      }
      return true
    }
    .sorted { ($0.indexedAtDate ?? .distantPast) < ($1.indexedAtDate ?? .distantPast) }
  }

  /// 通知の見出しと本文
  static func content(for item: NotificationItem) -> (title: String, body: String) {
    let name =
      item.author.displayName.flatMap { $0.isEmpty ? nil : $0 } ?? item.author.handle ?? ""
    let text = item.record?.text ?? ""
    guard let reason = NotificationReason(rawValue: item.reason) else { return (name, text) }
    switch reason {
    case .reply: return (String(localized: "\(name)さんが返信しました"), text)
    case .mention: return (String(localized: "\(name)さんがメンションしました"), text)
    case .quote: return (String(localized: "\(name)さんが引用しました"), text)
    case .like: return (String(localized: "\(name)さんがいいねしました"), "")
    case .repost: return (String(localized: "\(name)さんがリポストしました"), "")
    case .follow: return (String(localized: "\(name)さんにフォローされました"), "")
    }
  }

  private func deliver(_ items: [NotificationItem]) async {
    let center = UNUserNotificationCenter.current()
    // 上限を超えたときは新しいものを個別に出し、残りは件数だけ知らせる
    let individual = items.suffix(Self.maxNotificationsPerCheck)
    for item in individual {
      let (title, body) = Self.content(for: item)
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.threadIdentifier = item.reason
      content.userInfo = ["uri": item.uri, "reason": item.reason]
      try? await center.add(UNNotificationRequest(identifier: item.uri, content: content, trigger: nil))
    }

    let overflow = items.count - individual.count
    if overflow > 0 {
      let content = UNMutableNotificationContent()
      content.title = "Bluepicca"
      content.body = String(localized: "ほかに\(overflow)件の新しい通知があります")
      content.sound = .default
      try? await center.add(
        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
  }

  private func remember(_ uris: [String]) {
    guard !uris.isEmpty else { return }
    let all = (defaults.stringArray(forKey: notifiedUrisKey) ?? []) + uris
    defaults.set(Array(all.suffix(maxRememberedUris)), forKey: notifiedUrisKey)
  }

  /// 次の確認で基準点を置き直す。通知をオンにしたときやログアウト時に、たまった過去の通知を出さないようにする
  func resetBaseline() {
    defaults.removeObject(forKey: lastSeenKey)
    defaults.removeObject(forKey: notifiedUrisKey)
  }

  // MARK: - バックグラウンド更新

  /// 次のバックグラウンド更新を予約する。実際に走る時刻は iOS が決める
  func scheduleBackgroundRefresh() {
    guard settings.isEnabled else {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
      return
    }
    let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // シミュレータやバックグラウンド更新がオフの端末では失敗する
      dlog("Failed to schedule notification refresh: \(error)")
    }
  }

  func handleBackgroundRefresh() async {
    scheduleBackgroundRefresh()
    await checkForNewNotifications()
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// アプリを開いている間もバナーで出す
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}
