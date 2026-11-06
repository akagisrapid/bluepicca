import Foundation

struct SearchActorsApi {
  func searchActors(query: String, cursor: String? = nil) async throws -> SearchActorsResponse {
    let session = try await SessionManager.shared.getSession()
    let urlString = "https://bsky.social/xrpc/app.bsky.actor.searchActors"

    let params = SearchActorsRequest(q: query, limit: 50, cursor: cursor)
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    do {
      return try await HTTPClient.decode(
        SearchActorsResponse.self, urlString, query: params, headers: headers)
    } catch {
      dlog("SearchActors API error: \(error)")
      throw error
    }
  }
}
