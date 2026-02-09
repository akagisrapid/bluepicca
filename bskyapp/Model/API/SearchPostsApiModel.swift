import Foundation

struct SearchPostsRequest: Codable {
    var q: String
    var limit: Int?
    var cursor: String?
}

struct SearchPostsResponse: Codable {
    let cursor: String?
    let posts: [Post]
}
