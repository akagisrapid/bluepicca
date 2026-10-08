import Foundation

struct GetAuthorFeedApi {
  func getAuthorFeed(actor: String, limit: Int = 50, cursor: String? = nil) async throws
    -> FeedResponse
  {
    dlog("Fetching author feed from API for actor: \(actor)")

    let session = try await SessionManager.shared.getSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getAuthorFeed"
    let urlString = endPoint + repo

    var parameters: [String: Any] = [
      "actor": actor,
      "limit": limit,
    ]

    if let cursor = cursor {
      parameters["cursor"] = cursor
    }

    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    dlog("Making author feed request to: \(urlString)")

    do {
      let res = try await HTTPClient.decode(
        FeedResponse.self, urlString, query: parameters, headers: headers)
      dlog("Author feed API success: received \(res.feed.count) items for \(actor)")
      return res
    } catch {
      dlog("Author feed API error: \(error)")
      throw error
    }
  }
}
