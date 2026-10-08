import Foundation

struct HashtagPreferenceApi {
  private static let prefType = "app.bluepicca.hashtag#hashtagFeedPref"

  func getHashtags() async throws -> [String] {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = ["Authorization": "Bearer \(session.accessJwt)"]
    let url = "https://bsky.social/xrpc/app.bsky.actor.getPreferences"

    let data = try await HTTPClient.data(url, headers: headers)

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

    let data = try await HTTPClient.data(getUrl, headers: headers)

    guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw URLError(.cannotParseResponse)
    }

    var prefs = json["preferences"] as? [[String: Any]] ?? []
    prefs.removeAll { $0["$type"] as? String == Self.prefType }
    if !hashtags.isEmpty {
      prefs.append(["$type": Self.prefType, "hashtags": hashtags])
    }
    json["preferences"] = prefs

    let putUrl = "https://bsky.social/xrpc/app.bsky.actor.putPreferences"
    let putHeaders: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)",
      "Content-Type": "application/json",
    ]
    _ = try await HTTPClient.data(putUrl, method: .post, json: json, headers: putHeaders)
  }
}
