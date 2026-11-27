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
  // スターターパック用フィールド (app.bsky.graph.defs#starterPackViewBasic)
  // 名前と説明はポストの `value` ではなく `record` に入っている
  let record: StarterPackRecord?
  let listItemCount: Int?
  let joinedAllTimeCount: Int?

  var isFeedGenerator: Bool {
    recordType == "app.bsky.feed.defs#generatorView"
  }

  var isStarterPack: Bool {
    recordType == "app.bsky.graph.defs#starterPackViewBasic"
  }

  /// スターターパックの Web ページ（at://<did>/app.bsky.graph.starterpack/<rkey> → bsky.app/starter-pack/<did>/<rkey>）
  var starterPackWebUrl: URL? {
    guard isStarterPack, let uri, uri.hasPrefix("at://") else { return nil }
    let parts = uri.dropFirst("at://".count).split(separator: "/")
    guard parts.count == 3, parts[1] == "app.bsky.graph.starterpack" else { return nil }
    return URL(string: "https://bsky.app/starter-pack/\(parts[0])/\(parts[2])")
  }

  var avatarUrl: URL? {
    if let avatar { return URL(string: avatar) }
    return author?.avatarUrl
  }

  private enum CodingKeys: String, CodingKey {
    case recordType = "$type"
    case uri, author, value, embeds
    case displayName, description, avatar, creator
    case record, listItemCount, joinedAllTimeCount
  }
}

/// app.bsky.graph.starterpack レコード（表示に使う項目のみ）
struct StarterPackRecord: Codable {
  let name: String?
  let description: String?
}

struct QuotedPostEmbed: Codable {
  let images: [EmbedImagesViewItem]?
}
