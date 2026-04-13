import Foundation

struct CreateFollowRecord: Codable {
    let type: String = "app.bsky.graph.follow"
    let subject: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case subject, createdAt
    }
}

struct CreateFollowRequest: Codable {
    let repo: String
    let collection: String = "app.bsky.graph.follow"
    let rkey: String? = nil
    let validate: Bool? = nil
    let record: CreateFollowRecord
    let swapCommit: String? = nil
}

struct CreateFollowResponse: Codable {
    let uri: String
    let cid: String
}
