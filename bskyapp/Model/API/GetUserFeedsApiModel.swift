import Foundation

// MARK: - getPreferences

struct GetPreferencesResponse: Codable {
  let preferences: [PreferenceItem]
}

struct PreferenceItem: Codable {
  static let savedFeedsType = "app.bsky.actor.defs#savedFeedsPrefV2"

  let type: String?
  /// savedFeedsPrefV2 の items だけを読む。mutedWordsPref など、ほかの設定も items を持つが形が違うので無視する
  let items: [SavedFeedItem]?

  private enum CodingKeys: String, CodingKey {
    case type = "$type"
    case items
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    type = try c.decodeIfPresent(String.self, forKey: .type)
    items =
      type == Self.savedFeedsType
      ? try c.decodeIfPresent([SavedFeedItem].self, forKey: .items) : nil
  }
}

struct SavedFeedItem: Codable {
  let type: String  // "feed" | "list" | "timeline"
  let value: String  // AT URI (feed/list) or "following" (timeline)
  let pinned: Bool
  let id: String
}

// MARK: - getFeedGenerators

struct GetFeedGeneratorsResponse: Codable {
  let feeds: [FeedGeneratorView]
}

struct FeedGeneratorView: Codable {
  let uri: String
  let displayName: String
  let description: String?
  let avatar: String?
}

// MARK: - FeedTab（UI用）

struct FeedTab: Identifiable {
  let id: String
  let name: String
  let uri: String?  // nil = ホームTL or ハッシュタグ
  let hashtag: String?  // non-nil = ハッシュタグフィード
  let avatarUrl: URL?

  init(id: String, name: String, uri: String?, hashtag: String? = nil, avatarUrl: URL?) {
    self.id = id
    self.name = name
    self.uri = uri
    self.hashtag = hashtag
    self.avatarUrl = avatarUrl
  }

  static let home = FeedTab(id: "home", name: "ホーム", uri: nil, avatarUrl: nil)

  static func forHashtag(_ tag: String) -> FeedTab {
    FeedTab(id: "hashtag:\(tag)", name: "#\(tag)", uri: nil, hashtag: tag, avatarUrl: nil)
  }
}
