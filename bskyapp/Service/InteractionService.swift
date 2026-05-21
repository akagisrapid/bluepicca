import Alamofire
import Foundation

class InteractionService {
  static let shared = InteractionService()

  private let endPoint = "https://bsky.social/xrpc/"

  private init() {}

  // MARK: - Like

  func like(post: Post) async throws -> String {
    guard let uri = post.uri, let cid = post.cid else {
      throw NSError(
        domain: "InteractionService", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Invalid post data"])
    }

    let record: [String: Any] = [
      "$type": "app.bsky.feed.like",
      "subject": [
        "uri": uri,
        "cid": cid,
      ],
      "createdAt": Date().ISO8601Format(),
    ]

    return try await createRecord(collection: "app.bsky.feed.like", record: record)
  }

  func unlike(likeUri: String) async throws {
    try await deleteRecord(collection: "app.bsky.feed.like", rkey: getRKey(from: likeUri))
  }

  // MARK: - Repost

  func repost(post: Post) async throws -> String {
    guard let uri = post.uri, let cid = post.cid else {
      throw NSError(
        domain: "InteractionService", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Invalid post data"])
    }

    let record: [String: Any] = [
      "$type": "app.bsky.feed.repost",
      "subject": [
        "uri": uri,
        "cid": cid,
      ],
      "createdAt": Date().ISO8601Format(),
    ]

    return try await createRecord(collection: "app.bsky.feed.repost", record: record)
  }

  func unrepost(repostUri: String) async throws {
    try await deleteRecord(collection: "app.bsky.feed.repost", rkey: getRKey(from: repostUri))
  }

  // MARK: - Delete Post

  func deletePost(uri: String) async throws {
    try await deleteRecord(collection: "app.bsky.feed.post", rkey: getRKey(from: uri))
  }

  // MARK: - Private Helpers

  private func createRecord(collection: String, record: [String: Any]) async throws -> String {
    let session = try await SessionManager.shared.getSession()

    // パラメータを辞書として構築
    let parameters: [String: Any] = [
      "repo": session.did,
      "collection": collection,
      "record": record,
    ]

    let url = endPoint + "com.atproto.repo.createRecord"

    let headers: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)",
      "Content-Type": "application/json",
    ]

    let response = await AF.request(
      url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers
    )
    .serializingDecodable(CreateRecordResponse.self)  // 既存のレスポンス型を再利用
    .response

    switch response.result {
    case .success(let value):
      return value.uri ?? ""  // URIが存在しない場合は空文字を返す
    case .failure(let error):
      dlog("InteractionService createRecord error: \(error)")
      if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
        dlog("Server response: \(responseString)")
      }
      throw error
    }
  }

  private func deleteRecord(collection: String, rkey: String) async throws {
    let session = try await SessionManager.shared.getSession()

    let parameters: [String: Any] = [
      "repo": session.did,
      "collection": collection,
      "rkey": rkey,
    ]

    let url = endPoint + "com.atproto.repo.deleteRecord"

    let headers: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)",
      "Content-Type": "application/json",
    ]

    let response = await AF.request(
      url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers
    )
    .serializingData()
    .response

    switch response.result {
    case .success:
      return
    case .failure(let error):
      dlog("InteractionService deleteRecord error: \(error)")
      if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
        dlog("Server response: \(responseString)")
      }
      throw error
    }
  }

  private func getRKey(from uri: String) -> String {
    // at://did:plc:xxx/app.bsky.feed.like/rkey_value -> rkey_value
    return uri.components(separatedBy: "/").last ?? uri
  }
}
