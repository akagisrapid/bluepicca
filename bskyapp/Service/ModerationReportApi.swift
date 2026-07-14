import Alamofire
import Foundation

class ModerationReportApi {

  /// Blueskyの公式モデレーションサービス（mod.bsky.app）のDIDとservice id。
  /// PDSがこのヘッダーを見てcreateReportをモデレーションサービスへプロキシする。
  private static let labelerProxyHeaderValue = "did:plc:ar7c4by46qjdydhdevvrndac#atproto_labeler"

  static func createReport(uri: String, cid: String, reasonType: String, reason: String? = nil)
    async throws
  {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
      "atproto-proxy": labelerProxyHeaderValue,
    ]
    let requestBody = CreateReportRequest(
      reasonType: reasonType,
      reason: reason,
      subject: CreateReportSubject(type: "com.atproto.repo.strongRef", uri: uri, cid: cid)
    )
    return try await withCheckedThrowingContinuation { continuation in
      AF.request(
        "https://bsky.social/xrpc/com.atproto.moderation.createReport",
        method: .post,
        parameters: requestBody,
        encoder: JSONParameterEncoder.default,
        headers: headers
      )
      .validate()
      .responseDecodable(of: CreateReportResponse.self) { response in
        switch response.result {
        case .success: continuation.resume()
        case .failure(let error): continuation.resume(throwing: error)
        }
      }
    }
  }
}
