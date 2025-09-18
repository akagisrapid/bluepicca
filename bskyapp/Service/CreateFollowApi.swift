import Foundation
import Alamofire

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
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: requestBody, encoder: JSONParameterEncoder.default, headers: headers)
                .validate()
                .responseDecodable(of: CreateFollowResponse.self) { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

