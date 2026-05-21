import Alamofire
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

    let response = await AF.request(urlString, method: .get, parameters: params, headers: headers)
      .validate()
      .serializingDecodable(FeedResponse.self).response

    switch response.result {
    case .success(let res):
      return res
    case .failure(let error):
      dlog("GetFeedApi error: \(error)")
      throw error
    }
  }
}
