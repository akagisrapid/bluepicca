import Foundation

class MuteBlockApi {

  // MARK: - Mute

  static func muteActor(did: String) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    _ = try await HTTPClient.data(
      "https://bsky.social/xrpc/app.bsky.graph.muteActor", method: .post,
      json: MuteActorRequest(actor: did), headers: headers)
  }

  static func unmuteActor(did: String) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    _ = try await HTTPClient.data(
      "https://bsky.social/xrpc/app.bsky.graph.unmuteActor", method: .post,
      json: MuteActorRequest(actor: did), headers: headers)
  }

  static func getMutes(limit: Int = 50, cursor: String? = nil) async throws -> GetMutesResponse {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let params = GetMutesRequest(limit: limit, cursor: cursor)
    return try await HTTPClient.decode(
      GetMutesResponse.self, "https://bsky.social/xrpc/app.bsky.graph.getMutes", method: .get,
      query: params, headers: headers)
  }

  // MARK: - Block

  static func blockActor(did: String) async throws -> String {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let record = CreateBlockRecord(subject: did, createdAt: Date().ISO8601Format())
    let requestBody = CreateBlockRequest(repo: session.did, record: record)
    return try await HTTPClient.decode(
      CreateFollowResponse.self, "https://bsky.social/xrpc/com.atproto.repo.createRecord",
      method: .post, json: requestBody, headers: headers
    ).uri
  }

  static func unblockActor(uri: String) async throws {
    let session = try await SessionManager.shared.getSession()
    guard let rkey = uri.split(separator: "/").last else { throw APIError.invalidURI }
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let requestBody = DeleteBlockRequest(repo: session.did, rkey: String(rkey))
    _ = try await HTTPClient.data(
      "https://bsky.social/xrpc/com.atproto.repo.deleteRecord", method: .post, json: requestBody,
      headers: headers)
  }

  static func getBlocks(limit: Int = 50, cursor: String? = nil) async throws -> GetBlocksResponse {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let params = GetBlocksRequest(limit: limit, cursor: cursor)
    return try await HTTPClient.decode(
      GetBlocksResponse.self, "https://bsky.social/xrpc/app.bsky.graph.getBlocks", method: .get,
      query: params, headers: headers)
  }
}
