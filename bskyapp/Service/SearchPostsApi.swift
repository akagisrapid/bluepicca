import Foundation
import Alamofire

struct SearchPostsApi {
    func searchPosts(query: String, cursor: String? = nil) async throws -> SearchPostsResponse {
        let session = try await SessionManager.shared.getSession()
        let urlString = "https://bsky.social/xrpc/app.bsky.feed.searchPosts"

        let params = SearchPostsRequest(q: query, limit: 50, cursor: cursor)
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]

        let response = await AF.request(urlString, method: .get, parameters: params, headers: headers)
            .validate()
            .serializingDecodable(SearchPostsResponse.self).response

        switch response.result {
        case .success(let res):
            return res
        case .failure(let error):
            print("SearchPosts API error:")
            print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
            print("Status Code: \(response.response?.statusCode ?? 0)")
            print("Error: \(error)")
            throw error
        }
    }
}
