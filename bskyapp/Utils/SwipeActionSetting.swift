import Foundation

enum SwipeAction: String, CaseIterable {
  case like = "like"
  case repost = "repost"
  case reply = "reply"
  case bookmark = "bookmark"
  case quote = "quote"
  case none = "none"

  var label: String {
    switch self {
    case .like: return String(localized: "いいね")
    case .repost: return String(localized: "リポスト")
    case .reply: return String(localized: "返信")
    case .bookmark: return String(localized: "ブックマーク")
    case .quote: return String(localized: "引用ポスト")
    case .none: return String(localized: "なし")
    }
  }

  var icon: String {
    switch self {
    case .like: return "star.fill"
    case .repost: return "arrow.rectanglepath"
    case .reply: return "bubble.left.fill"
    case .bookmark: return "bookmark.fill"
    case .quote: return "quote.bubble.fill"
    case .none: return "minus"
    }
  }
}
