import Foundation
import Alamofire

class GetFollowsApi {
    static func getFollows(param: GetFollowsApiRequest) async throws -> GetFollowsApiResponse {
        let session = try await SessionManager.shared.getSession()
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        
        var urlComponents = URLComponents(string: "https://bsky.social/xrpc/app.bsky.graph.getFollows")!
        urlComponents.queryItems = [
            URLQueryItem(name: "actor", value: param.actor)
        ]
        
        if let limit = param.limit {
            urlComponents.queryItems?.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        
        if let cursor = param.cursor {
            urlComponents.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: headers)
                .validate()
                .responseDecodable(of: GetFollowsApiResponse.self) { response in
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
