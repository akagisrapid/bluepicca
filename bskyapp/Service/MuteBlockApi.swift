import Alamofire
import Foundation

class MuteBlockApi {

  // MARK: - Mute

  static func muteActor(did: String) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/app.bsky.graph.muteActor",
        method: .post,
        parameters: MuteActorRequest(actor: did),
        encoder: JSONParameterEncoder.default,
        headers: headers
      )
      .validate()
      .response { response in
        switch response.result {
        case .success: continuation.resume()
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }

  static func unmuteActor(did: String) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/app.bsky.graph.unmuteActor",
        method: .post,
        parameters: MuteActorRequest(actor: did),
        encoder: JSONParameterEncoder.default,
        headers: headers
      )
      .validate()
      .response { response in
        switch response.result {
        case .success: continuation.resume()
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }

  static func getMutes(limit: Int = 50, cursor: String? = nil) async throws -> GetMutesResponse {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let params = GetMutesRequest(limit: limit, cursor: cursor)
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/app.bsky.graph.getMutes",
        method: .get,
        parameters: params,
        headers: headers
      )
      .validate()
      .responseDecodable(of: GetMutesResponse.self) { response in
        switch response.result {
        case .success(let data): continuation.resume(returning: data)
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
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
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/com.atproto.repo.createRecord",
        method: .post,
        parameters: requestBody,
        encoder: JSONParameterEncoder.default,
        headers: headers
      )
      .validate()
      .responseDecodable(of: CreateFollowResponse.self) { response in
        switch response.result {
        case .success(let data): continuation.resume(returning: data.uri)
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }

  static func unblockActor(uri: String) async throws {
    let session = try await SessionManager.shared.getSession()
    guard let rkey = uri.split(separator: "/").last else { throw APIError.invalidURI }
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let requestBody = DeleteBlockRequest(repo: session.did, rkey: String(rkey))
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/com.atproto.repo.deleteRecord",
        method: .post,
        parameters: requestBody,
        encoder: JSONParameterEncoder.default,
        headers: headers
      )
      .validate()
      .response { response in
        switch response.result {
        case .success: continuation.resume()
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }

  static func getBlocks(limit: Int = 50, cursor: String? = nil) async throws -> GetBlocksResponse {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]
    let params = GetBlocksRequest(limit: limit, cursor: cursor)
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/app.bsky.graph.getBlocks",
        method: .get,
        parameters: params,
        headers: headers
      )
      .validate()
      .responseDecodable(of: GetBlocksResponse.self) { response in
        switch response.result {
        case .success(let data): continuation.resume(returning: data)
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }
}
