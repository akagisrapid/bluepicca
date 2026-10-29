import Foundation

/// 端末に通知を出す対象。rawValue は listNotifications の `reason` と同じ
enum NotificationReason: String, CaseIterable {
  case reply
  case mention
  case quote
  case like
  case repost
  case follow

  var label: String {
    switch self {
    case .reply: return String(localized: "返信")
    case .mention: return String(localized: "メンション")
    case .quote: return String(localized: "引用")
    case .like: return String(localized: "いいね")
    case .repost: return String(localized: "リポスト")
    case .follow: return String(localized: "フォロー")
    }
  }

  /// 初回に有効にしておく対象。自分宛の会話だけを既定で通知する
  static let defaultEnabled: Set<NotificationReason> = [.reply, .mention, .quote]
}

/// 通知のオン・オフと対象を UserDefaults に保存する
class NotificationSettings: ObservableObject {
  static let shared = NotificationSettings()

  private let enabledKey = "pushNotificationEnabled"
  private let reasonsKey = "pushNotificationReasons"

  @Published var isEnabled: Bool {
    didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
  }

  @Published var enabledReasons: Set<NotificationReason> {
    didSet {
      UserDefaults.standard.set(enabledReasons.map(\.rawValue).sorted(), forKey: reasonsKey)
    }
  }

  private init() {
    isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    if let raw = UserDefaults.standard.stringArray(forKey: reasonsKey) {
      enabledReasons = Set(raw.compactMap(NotificationReason.init(rawValue:)))
    } else {
      enabledReasons = NotificationReason.defaultEnabled
    }
  }

  func isSelected(_ reason: NotificationReason) -> Bool {
    enabledReasons.contains(reason)
  }

  func setSelected(_ reason: NotificationReason, _ selected: Bool) {
    if selected {
      enabledReasons.insert(reason)
    } else {
      enabledReasons.remove(reason)
    }
  }
}
