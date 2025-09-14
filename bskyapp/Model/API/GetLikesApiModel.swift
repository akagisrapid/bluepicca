import Foundation

struct GetLikesApiRequest : Codable {
    var uri: String
    var cid: String?
    var limit: Int?
    var cursor: String?
}

struct GetLikesApiResponse: Codable {
    var uri: String
    var cid: String?
    var cursor: String?
    var likes: [Like]
}

struct Like: Codable {
    var createdAt: String
    var indexedAt: String
    var actor: Author
}
