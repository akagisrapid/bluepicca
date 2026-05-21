import Alamofire
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

    // Alamofire request
    let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
      .validate()
      .serializingDecodable(FeedResponse.self, decoder: decoder)
      .response

    switch response.result {
    case .success(let res):
      return res
    case .failure(let error):
      dlog("Error in GetActorLikesApi: \(error)")
      if let data = response.data, let str = String(data: data, encoding: .utf8) {
        dlog("Response body: \(str)")
      }
      throw error
    }
  }
}
