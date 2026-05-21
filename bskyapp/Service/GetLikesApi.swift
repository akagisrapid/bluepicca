import Alamofire
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
      let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
        .validate()
        .serializingDecodable(GetLikesApiResponse.self).response
      switch response.result {
      case .success(let res):
        return res
      case .failure(let error):
        dlog(response.request?.url)
        dlog(response.response?.statusCode)
        dlog(error)
        throw error
      }
    } catch {
      throw error
    }
  }
}
