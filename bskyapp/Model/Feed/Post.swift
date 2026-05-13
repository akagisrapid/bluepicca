import Foundation

class Post: Codable, ObservableObject, Identifiable {
  var id: String { uri ?? cid ?? ObjectIdentifier(self).debugDescription }
  let uri: String?
  let cid: String?
  let author: Author?
  let record: PostRecord?
  let embed: Embed?
  let replyCount: Int?
  @Published var repostCount: Int?
  @Published var likeCount: Int?
  let indexedAt: String?
  @Published var viewer: Viewer?
  let labels: [Label]?
  let threadgate: Threadgate?

  enum CodingKeys: String, CodingKey {
    case uri, cid, author, record, embed, replyCount, repostCount, likeCount, indexedAt, viewer,
      labels, threadgate
  }

  required init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uri = try c.decodeIfPresent(String.self, forKey: .uri)
    cid = try c.decodeIfPresent(String.self, forKey: .cid)
    author = try c.decodeIfPresent(Author.self, forKey: .author)
    record = try c.decodeIfPresent(PostRecord.self, forKey: .record)
    embed = try c.decodeIfPresent(Embed.self, forKey: .embed)
    replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount)
    repostCount = try c.decodeIfPresent(Int.self, forKey: .repostCount)
    likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount)
    indexedAt = try c.decodeIfPresent(String.self, forKey: .indexedAt)
    viewer = try c.decodeIfPresent(Viewer.self, forKey: .viewer)
    labels = try c.decodeIfPresent([Label].self, forKey: .labels)
    threadgate = try c.decodeIfPresent(Threadgate.self, forKey: .threadgate)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(uri, forKey: .uri)
    try c.encodeIfPresent(cid, forKey: .cid)
    try c.encodeIfPresent(author, forKey: .author)
    try c.encodeIfPresent(record, forKey: .record)
    try c.encodeIfPresent(embed, forKey: .embed)
    try c.encodeIfPresent(replyCount, forKey: .replyCount)
    try c.encodeIfPresent(repostCount, forKey: .repostCount)
    try c.encodeIfPresent(likeCount, forKey: .likeCount)
    try c.encodeIfPresent(indexedAt, forKey: .indexedAt)
    try c.encodeIfPresent(viewer, forKey: .viewer)
    try c.encodeIfPresent(labels, forKey: .labels)
    try c.encodeIfPresent(threadgate, forKey: .threadgate)
  }

  init(
    uri: String?, cid: String?, author: Author?, record: PostRecord?,
    embed: Embed? = nil, replyCount: Int? = nil, repostCount: Int? = nil,
    likeCount: Int? = nil, indexedAt: String? = nil, viewer: Viewer? = nil,
    labels: [Label]? = nil, threadgate: Threadgate? = nil
  ) {
    self.uri = uri
    self.cid = cid
    self.author = author
    self.record = record
    self.embed = embed
    self.replyCount = replyCount
    self.repostCount = repostCount
    self.likeCount = likeCount
    self.indexedAt = indexedAt
    self.viewer = viewer
    self.labels = labels
    self.threadgate = threadgate
  }
}

extension Post {
  private static let sensitiveLabels: Set<String> = [
    "porn", "sexual", "nudity", "graphic-media", "nsfw",
  ]

  var isSensitive: Bool {
    guard let labels = labels else { return false }
    return labels.contains { Post.sensitiveLabels.contains($0.val) && $0.neg != true }
  }
}
