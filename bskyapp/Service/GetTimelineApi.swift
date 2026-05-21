import Alamofire
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

    let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
      .validate()
      .serializingDecodable(FeedResponse.self).response

    switch response.result {
    case .success(let res):
      dlog("Timeline API success: received \(res.feed.count) items")
      return res
    case .failure(let error):
      dlog("Timeline API error:")
      dlog("URL: \(response.request?.url?.absoluteString ?? "unknown")")
      dlog("Status Code: \(response.response?.statusCode ?? 0)")
      dlog("Error: \(error)")
      throw error
    }
  }
}
