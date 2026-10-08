import Foundation

struct GetFeedApi {
  func getFeed(uri: String, cursor: String? = nil) async throws -> FeedResponse {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)"
    ]

    struct Params: Encodable {
      let feed: String
      let limit: Int
      let cursor: String?
    }

    let params = Params(feed: uri, limit: 50, cursor: cursor)
    let urlString = "https://bsky.social/xrpc/app.bsky.feed.getFeed"

    do {
      return try await HTTPClient.decode(
        FeedResponse.self, urlString, query: params, headers: headers)
    } catch {
      dlog("GetFeedApi error: \(error)")
      throw error
    }
  }
}
