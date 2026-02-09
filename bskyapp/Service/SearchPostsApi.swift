import Foundation
import Alamofire

struct SearchPostsApi {
    func searchPosts(param: SearchPostsRequest) async throws -> SearchPostsResponse {
        let session = try await SessionManager.shared.getSession()
        let endPoint = "https://bsky.social/xrpc/"
        let repo = "app.bsky.feed.searchPosts"
        let urlString = endPoint + repo

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]

        let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
            .validate()
            .serializingDecodable(SearchPostsResponse.self).response

        switch response.result {
        case .success(let res):
            return res
        case .failure(let error):
            print("SearchPosts API error: \(error)")
            throw error
        }
    }
}
