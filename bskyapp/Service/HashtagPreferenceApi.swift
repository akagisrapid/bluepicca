import Alamofire
import Foundation

struct HashtagPreferenceApi {
  private static let prefType = "app.bluepicca.hashtag#hashtagFeedPref"

  func getHashtags() async throws -> [String] {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = ["Authorization": "Bearer \(session.accessJwt)"]
    let url = "https://bsky.social/xrpc/app.bsky.actor.getPreferences"

    let response = await AF.request(url, method: .get, headers: headers)
      .validate()
      .serializingData().response

    guard case .success(let data) = response.result else {
      throw response.error ?? URLError(.badServerResponse)
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let prefs = json["preferences"] as? [[String: Any]]
    else {
      return []
    }

    return
      prefs
      .first(where: { $0["$type"] as? String == Self.prefType })
      .flatMap { $0["hashtags"] as? [String] } ?? []
  }

  func putHashtags(_ hashtags: [String]) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = ["Authorization": "Bearer \(session.accessJwt)"]
    let getUrl = "https://bsky.social/xrpc/app.bsky.actor.getPreferences"

    let getResponse = await AF.request(getUrl, method: .get, headers: headers)
      .validate()
      .serializingData().response

    guard case .success(let data) = getResponse.result else {
      throw getResponse.error ?? URLError(.badServerResponse)
    }

    guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw URLError(.cannotParseResponse)
    }

    var prefs = json["preferences"] as? [[String: Any]] ?? []
    prefs.removeAll { $0["$type"] as? String == Self.prefType }
    if !hashtags.isEmpty {
      prefs.append(["$type": Self.prefType, "hashtags": hashtags])
    }
    json["preferences"] = prefs

    let body = try JSONSerialization.data(withJSONObject: json)
    let putUrl = "https://bsky.social/xrpc/app.bsky.actor.putPreferences"
    let putHeaders: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)",
      "Content-Type": "application/json",
    ]

    var request = URLRequest(url: URL(string: putUrl)!)
    request.httpMethod = "POST"
    request.httpBody = body
    putHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.name) }

    let putResponse = await AF.request(request)
      .validate()
      .serializingData().response

    if case .failure(let error) = putResponse.result {
      throw error
    }
  }
}
