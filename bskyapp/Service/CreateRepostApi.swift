import Foundation
import Alamofire

struct CreateRepostRequest: Codable {
    let repo: String
    let collection: String = "app.bsky.feed.repost"
    let record: RepostRecord
}

struct RepostRecord: Codable {
    let subject: RepostSubject
    let createdAt: String
    
    private enum CodingKeys: String, CodingKey {
        case subject, createdAt
    }
}

struct RepostSubject: Codable {
    let uri: String
    let cid: String
}

struct CreateRepostResponse: Codable {
    let uri: String
    let cid: String
}

func createRepost(postUri: String, postCid: String) async throws -> CreateRepostResponse {
    let endPoint = "https://bsky.social/xrpc/"
    let createRecord = "com.atproto.repo.createRecord"
    
    let session = try await SessionManager.shared.getSession()
    let urlString = endPoint + createRecord
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)"
    ]
    
    let repostRecord = RepostRecord(
        subject: RepostSubject(uri: postUri, cid: postCid),
        createdAt: Date().ISO8601Format()
    )
    
    let request = CreateRepostRequest(
        repo: session.did,
        record: repostRecord
    )
    
    print("リポストリクエスト: \(request)")
    
    let response = await AF.request(
        urlString,
        method: .post,
        parameters: request,
        encoder: JSONParameterEncoder.default,
        headers: headers
    )
    .validate()
    .serializingDecodable(CreateRepostResponse.self)
    .response
    
    switch response.result {
    case .success(let value):
        print("リポスト成功: \(value)")
        return value
    case .failure(let error):
        print("リポスト失敗: \(error)")
        print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
        print("ステータスコード: \(response.response?.statusCode ?? 0)")
        
        if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
            print("レスポンスボディ: \(responseString)")
        }
        
        throw error
    }
}
