import Foundation

struct SearchPostsRequest: Codable {
    let q: String
    let limit: Int?
    let cursor: String?
}

struct SearchPostsResponse: Codable {
    let cursor: String?
    let hitsTotal: Int?
    let posts: [Post]
}
