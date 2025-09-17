import Foundation
import Alamofire

// MARK: - いいね作成のレスポンス
struct CreateLikeResponse: Codable {
    let uri: String
    let cid: String
}

// MARK: - いいね作成のリクエスト
struct CreateLikeRequest: Codable {
    let repo: String
    let collection: String = "app.bsky.feed.like"
    let record: LikeRecord
}

struct LikeRecord: Codable {
    let subject: LikeSubject
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case subject, createdAt
    }
}

struct LikeSubject: Codable {
    let uri: String
    let cid: String
}

// MARK: - いいね作成API
func createLike(postUri: String, postCid: String) async throws -> CreateLikeResponse {
    let session = try await SessionManager.shared.getSession()
    
    let likeRecord = LikeRecord(
        subject: LikeSubject(uri: postUri, cid: postCid),
        createdAt: Date().ISO8601Format()
    )
    
    let request = CreateLikeRequest(
        repo: session.did,
        record: likeRecord
    )
    
    print("いいねリクエスト: \(request)")
    
    let endPoint = "https://bsky.social/xrpc/"
    let createRecord = "com.atproto.repo.createRecord"
    let urlString = endPoint + createRecord
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)"
    ]
    
    let response = await AF.request(urlString, method: .post, parameters: request, encoder: JSONParameterEncoder.default, headers: headers)
        .validate()
        .serializingDecodable(CreateLikeResponse.self)
        .response
    
    switch response.result {
    case .success(let value):
        print("いいね成功: \(value)")
        return value
    case .failure(let error):
        print("いいね失敗: \(error)")
        print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
        print("ステータスコード: \(response.response?.statusCode ?? 0)")
        
        if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
            print("レスポンスボディ: \(responseString)")
        }
        
        throw error
    }
}

// MARK: - いいね削除API
func deleteLike(likeUri: String) async throws {
    let session = try await SessionManager.shared.getSession()
    
    // URIからrkey（レコードキー）を抽出
    guard let rkey = extractRkeyFromUri(likeUri) else {
        throw NSError(domain: "InvalidURI", code: 0, userInfo: [NSLocalizedDescriptionKey: "無効ないいねURIです"])
    }
    
    let endPoint = "https://bsky.social/xrpc/"
    let deleteRecord = "com.atproto.repo.deleteRecord"
    let urlString = endPoint + deleteRecord
    
    let parameters: [String: Any] = [
        "repo": session.did,
        "collection": "app.bsky.feed.like",
        "rkey": rkey
    ]
    
    print("いいね削除リクエスト: \(parameters)")
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)"
    ]
    
    let response = await AF.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
        .validate()
        .serializingData()
        .response
    
    switch response.result {
    case .success:
        print("いいね削除成功")
    case .failure(let error):
        print("いいね削除失敗: \(error)")
        print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
        print("ステータスコード: \(response.response?.statusCode ?? 0)")
        
        if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
            print("レスポンスボディ: \(responseString)")
        }
        
        throw error
    }
}

// MARK: - ヘルパー関数
private func extractRkeyFromUri(_ uri: String) -> String? {
    // URI形式: at://did:plc:xxx/app.bsky.feed.like/yyy
    // rkeyは最後の部分（yyy）
    let components = uri.components(separatedBy: "/")
    return components.last
}
