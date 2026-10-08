import Foundation

// HTTPHeadersExtensionからgetHeaders関数を使用するため
// getHeaders関数はUtils/Extension/HTTPHeadersExtension.swiftで定義されている

class CreateFollowApi {
    static func createFollow(actorDid: String) async throws -> CreateFollowResponse {
        let session = try await SessionManager.shared.getSession()
        
        let record = CreateFollowRecord(subject: actorDid, createdAt: Date().ISO8601Format())
        let requestBody = CreateFollowRequest(
            repo: session.did,
            record: record
        )
        let headers: HTTPHeaders =
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        let url = "https://bsky.social/xrpc/com.atproto.repo.createRecord"
        
        return try await HTTPClient.decode(
            CreateFollowResponse.self, url, method: .post, json: requestBody, headers: headers)
    }
}

