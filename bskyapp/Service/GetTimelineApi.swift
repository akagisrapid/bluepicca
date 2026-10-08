import Foundation

struct GetTimelineApi {
  func getTimeline(cursor: String? = nil) async throws -> FeedResponse {
    dlog("Fetching timeline from API (cursor: \(cursor ?? "nil"))")

    let session = try await SessionManager.shared.getSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getTimeline"
    let urlString = endPoint + repo

    let param: FeedRequest = FeedRequest(algorithm: "", limit: 50, cursor: cursor)
    let headers: HTTPHeaders =
      [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)",
      ]

    dlog("Making timeline request to: \(urlString)")

    do {
      let res = try await HTTPClient.decode(
        FeedResponse.self, urlString, query: param, headers: headers)
      dlog("Timeline API success: received \(res.feed.count) items")
      return res
    } catch {
      dlog("Timeline API error: \(error)")
      throw error
    }
  }
}
