import Foundation

struct GetPostThreadApi {
  func getPostThread(uri: String) async throws -> PostThreadResponse {
    let session = try await SessionManager.shared.getSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getPostThread"
    let urlString = endPoint + repo

    let parameters: [String: String] = [
      "uri": uri
    ]

    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    do {
      return try await HTTPClient.decode(
        PostThreadResponse.self, urlString, query: parameters, headers: headers)
    } catch {
      dlog(error)
      throw error
    }
  }
}
