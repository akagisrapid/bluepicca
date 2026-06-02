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
    case .like: return "いいね"
    case .repost: return "リポスト"
    case .reply: return "返信"
    case .bookmark: return "ブックマーク"
    case .quote: return "引用ポスト"
    case .none: return "なし"
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
