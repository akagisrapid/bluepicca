import Foundation

class FeedItem: Codable, ObservableObject {
    let post: Post
    let reply: Reply?
    let reason: Reason?
}
