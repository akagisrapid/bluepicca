import Foundation
import Alamofire

public struct UploadBlobResponse: Codable {
    public let blob: BlobReference
}

// 他のファイルからも参照できるように、publicキーワードを追加
public struct BlobReference: Codable {
    public let cid: String
    public let mimeType: String
}

public func uploadBlob(imageData: Data, mimeType: String) async throws -> UploadBlobResponse {
    let endPoint = "https://bsky.social/xrpc/"
    let uploadBlob = "com.atproto.repo.uploadBlob"
    
    let session = try await SessionManager.shared.getSession()
    let urlString = endPoint + uploadBlob
    
    let headers: HTTPHeaders = [
        "Content-Type": mimeType,
        "Authorization": "Bearer \(session.accessJwt)"
    ]
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    do {
        let response = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
            .validate()
            .serializingDecodable(UploadBlobResponse.self)
            .response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            print(response.request?.url)
            print(response.response?.statusCode)
            print(error)
            throw error
        }
    } catch {
        throw error
    }
}
