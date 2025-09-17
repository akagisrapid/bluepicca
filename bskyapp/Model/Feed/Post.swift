import Foundation

class Post: Codable, ObservableObject {
    let uri: String?
    let cid: String?
    let author: Author?
    let record: PostRecord?
    let embed: Embed?
    let replyCount: Int?
    var repostCount: Int?
    let likeCount: Int?
    let indexedAt: String?
    let viewer: Viewer?
    let labels: [Label]?
    let threadgate: Threadgate?
}
