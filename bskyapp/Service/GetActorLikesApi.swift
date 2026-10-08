import Foundation

struct GetActorLikesApi {
  func getActorLikes(param: GetActorLikesRequest) async throws -> FeedResponse {
    let session = try await SessionManager.shared.getSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getActorLikes"
    let urlString = endPoint + repo

    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      return try await HTTPClient.decode(
        FeedResponse.self, urlString, query: param, headers: headers, decoder: decoder)
    } catch {
      dlog("Error in GetActorLikesApi: \(error)")
      throw error
    }
  }
}
