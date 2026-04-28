import Foundation

struct EmbeddedRecordViewItem: Codable {
  /// "$type" の値（例: "app.bsky.feed.defs#generatorView", "app.bsky.feed.post#view"）
  let recordType: String?
  // ポスト用フィールド
  let uri: String?
  let author: Author?
  let value: PostRecord?
  let embeds: [QuotedPostEmbed]?
  // フィードジェネレーター用フィールド (app.bsky.feed.defs#generatorView)
  let displayName: String?
  let description: String?
  let avatar: String?
  let creator: Author?

  var isFeedGenerator: Bool {
    recordType == "app.bsky.feed.defs#generatorView"
  }

  var avatarUrl: URL? {
    if let avatar { return URL(string: avatar) }
    return author?.avatarUrl
  }

  private enum CodingKeys: String, CodingKey {
    case recordType = "$type"
    case uri, author, value, embeds
    case displayName, description, avatar, creator
  }
}

struct QuotedPostEmbed: Codable {
  let images: [EmbedImagesViewItem]?
}
