import Alamofire
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

    let response = await AF.request(
      urlString, method: .get, parameters: parameters, headers: headers
    )
    .validate()
    .serializingDecodable(FeedResponse.self).response

    switch response.result {
    case .success(let res):
      dlog("Author feed API success: received \(res.feed.count) items for \(actor)")
      return res
    case .failure(let error):
      dlog("Author feed API error:")
      dlog("URL: \(response.request?.url?.absoluteString ?? "unknown")")
      dlog("Status Code: \(response.response?.statusCode ?? 0)")
      dlog("Error: \(error)")
      throw error
    }
  }
}
