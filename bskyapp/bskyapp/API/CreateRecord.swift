import Foundation
struct CreateRecordRequest: Codable{
    let repo: String
    let collection: String
    let record: Record
    
    init(did: String, text: String, createdAt: Date) {
        repo = did
        collection = "app.bsky.feed.post"
        let createdAt = ISO8601DateFormatter().string(from: createdAt)
        record = .init(text: text, createdAt: createdAt, type: collection)
    }
}
/// 投稿レスポンス
struct CreateRecordResponse: Codable {
    let uri: String
    let cid: String
}

struct PostItem{
    let text: String
    let postDate: Date
}
func createRecord(session: CreateSessionResponse, postItem: PostItem) async throws -> CreateRecordResponse{
    let endPoint = "https://bsky.social/xrpc/"
    let createRecord = "com.atproto.repo.createRecord"
    let httpMethod = HttpMethodType.post
    let urlString = endPoint + createRecord
    
    var req = URLRequest(url: URL(string: urlString)!)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
    req.httpBody = try JSONEncoder().encode(
        CreateRecordRequest(did: session.did, text: postItem.text, createdAt: postItem.postDate)
    )
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else{
        print(response)
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(CreateRecordResponse.self, from: data)
}
