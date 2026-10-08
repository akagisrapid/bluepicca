import Foundation

struct GetLikesApi {
  func getLikes(param: GetLikesApiRequest) async throws -> GetLikesApiResponse {
    let session = try await SessionManager.shared.getSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getLikes"
    let urlString = endPoint + repo

    let headers: HTTPHeaders =
      [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)",
      ]
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    do {
      return try await HTTPClient.decode(
        GetLikesApiResponse.self, urlString, query: param, headers: headers)
    } catch {
      dlog(error)
      throw error
    }
  }
}
