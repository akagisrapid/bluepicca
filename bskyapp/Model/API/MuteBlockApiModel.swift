import Foundation

// MARK: - Mute
struct MuteActorRequest: Encodable {
    let actor: String
}

struct GetMutesRequest: Encodable {
    let limit: Int?
    let cursor: String?
}

struct GetMutesResponse: Decodable {
    let cursor: String?
    let subjects: [ModeratedSubject]
}

// MARK: - Block
struct CreateBlockRecord: Encodable {
    let type: String = "app.bsky.graph.block"
    let subject: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case subject, createdAt
    }
}

struct CreateBlockRequest: Encodable {
    let repo: String
    let collection: String = "app.bsky.graph.block"
    let record: CreateBlockRecord
}

struct DeleteBlockRequest: Encodable {
    let repo: String
    let collection: String = "app.bsky.graph.block"
    let rkey: String
}

struct GetBlocksRequest: Encodable {
    let limit: Int?
    let cursor: String?
}

struct GetBlocksResponse: Decodable {
    let cursor: String?
    let blocks: [BlockedSubject]
}

struct BlockedSubject: Decodable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let viewer: BlockedSubjectViewer?
}

struct BlockedSubjectViewer: Decodable {
    let blocking: String?
}

// MARK: - 共通モデル（ミュート一覧用）
struct ModeratedSubject: Decodable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
}
