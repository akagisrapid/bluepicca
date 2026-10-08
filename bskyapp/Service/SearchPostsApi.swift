import Foundation

struct SearchPostsApi {
  func searchPosts(query: String, cursor: String? = nil) async throws -> SearchPostsResponse {
    let session = try await SessionManager.shared.getSession()
    let urlString = "https://bsky.social/xrpc/app.bsky.feed.searchPosts"

    let params = SearchPostsRequest(q: query, limit: 50, cursor: cursor)
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    do {
      return try await HTTPClient.decode(
        SearchPostsResponse.self, urlString, query: params, headers: headers)
    } catch {
      dlog("SearchPosts API error: \(error)")
      throw error
    }
  }
}
