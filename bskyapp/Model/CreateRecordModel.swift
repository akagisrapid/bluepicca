import Foundation

struct CreateRecordPostItem: Codable {
    let text: String
    let createdAt: String?
    let embed: Embed?
}

struct CreateRecordRequest: Codable{
    var repo: String
    let collection: String
    let rkey: String?
    let validate: Bool?
    let record: CreateRecordPostItem
    let swapCommit: String?
}
func makeCreateRecordRequest(text: String) async throws -> CreateRecordRequest{
    let record = CreateRecordPostItem(
        text: text, createdAt:
            Date().ISO8601Format(),
        embed: nil)
    let session = try await createSession()
    let collection = "app.bsky.feed.post"
    return CreateRecordRequest(
        repo: session.did,
        collection: collection,
        rkey: nil,
        validate : nil,
        record: record,
        swapCommit: nil)
}


/// 投稿レスポンス
struct CreateRecordResponse: Codable {
    let uri: String?
    let cid: String?
}
