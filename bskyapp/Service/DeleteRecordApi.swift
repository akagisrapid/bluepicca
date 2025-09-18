import Foundation
import Alamofire

// HTTPHeadersExtensionからgetHeaders関数を使用するため
// getHeaders関数はUtils/Extension/HTTPHeadersExtension.swiftで定義されている

class DeleteRecordApi {
    static func deleteRecord(uri: String) async throws -> DeleteRecordResponse {
        let session = try await SessionManager.shared.getSession()
        
        guard let rkey = uri.split(separator: "/").last else {
            throw APIError.invalidURI
        }
        
        let requestBody = DeleteRecordRequest(
            repo: session.did,
            collection: "app.bsky.graph.follow", // フォローレコードの削除に特化
            rkey: String(rkey),
            swapRecord: nil,
            swapCommit: nil
        )
        
        let url = "https://bsky.social/xrpc/com.atproto.repo.deleteRecord"
        let headers: HTTPHeaders =
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: requestBody, encoder: JSONParameterEncoder.default, headers: headers)
                .validate()
                .responseDecodable(of: DeleteRecordResponse.self) { response in
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

enum APIError: Error {
    case invalidURI
}
