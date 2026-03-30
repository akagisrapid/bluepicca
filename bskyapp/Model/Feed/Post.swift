import Foundation

class Post: Codable, ObservableObject {
    let uri: String?
    let cid: String?
    let author: Author?
    let record: PostRecord?
    let embed: Embed?
    let replyCount: Int?
    var repostCount: Int?
    var likeCount: Int?
    let indexedAt: String?
    var viewer: Viewer?
    let labels: [Label]?
    let threadgate: Threadgate?

    init(uri: String?, cid: String?, author: Author?, record: PostRecord?,
         embed: Embed? = nil, replyCount: Int? = nil, repostCount: Int? = nil,
         likeCount: Int? = nil, indexedAt: String? = nil, viewer: Viewer? = nil,
         labels: [Label]? = nil, threadgate: Threadgate? = nil) {
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
