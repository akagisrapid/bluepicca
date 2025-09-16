import Foundation
import Alamofire

public struct UploadBlobResponse: Codable {
    public let blob: BlobReference
    
    // 手動で初期化するためのイニシャライザ
    public init(blob: BlobReference) {
        self.blob = blob
    }
    
    // デコード用の初期化メソッドを追加
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            // まず、blobフィールドを取得
            if let blobContainer = try? container.nestedContainer(keyedBy: BlobCodingKeys.self, forKey: .blob) {
                // 標準的なレスポンス形式の場合
                if let cid = try? blobContainer.decode(String.self, forKey: .cid),
                   let mimeType = try? blobContainer.decode(String.self, forKey: .mimeType) {
                    blob = BlobReference(cid: cid, mimeType: mimeType)
                    return
                }
                
                // refフィールドがある場合
                if let refContainer = try? blobContainer.nestedContainer(keyedBy: RefCodingKeys.self, forKey: .ref) {
                    if let link = try? refContainer.decode(String.self, forKey: .link) {
                        let mimeType = try blobContainer.decode(String.self, forKey: .mimeType)
                        blob = BlobReference(cid: link, mimeType: mimeType)
                        return
                    }
                }
            }
            
            // 別の形式の場合、直接オブジェクトとして取得
            blob = try container.decode(BlobReference.self, forKey: .blob)
        } catch {
            print("UploadBlobResponse デコードエラー: \(error)")
            
            // デコードに失敗した場合はエラーを投げる
            throw error
        }
    }
    
    // エンコード用のメソッドを追加
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blob, forKey: .blob)
    }
    
    private enum CodingKeys: String, CodingKey {
        case blob
    }
    
    private enum BlobCodingKeys: String, CodingKey {
        case cid, mimeType, ref
    }
    
    private enum RefCodingKeys: String, CodingKey {
        case link = "$link"
    }
}

// 他のファイルからも参照できるように、publicキーワードを追加
public struct BlobReference: Codable {
    public let cid: String
    public let mimeType: String
    
    // デコード用の初期化メソッドを追加
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 標準的な形式の場合
        if let cid = try? container.decode(String.self, forKey: .cid),
           let mimeType = try? container.decode(String.self, forKey: .mimeType) {
            self.cid = cid
            self.mimeType = mimeType
            return
        }
        
        // 別の形式の場合、refフィールドから取得
        if let refContainer = try? container.nestedContainer(keyedBy: RefCodingKeys.self, forKey: .ref) {
            if let link = try? refContainer.decode(String.self, forKey: .link) {
                self.cid = link
                self.mimeType = try container.decode(String.self, forKey: .mimeType)
                return
            }
        }
        
        // それでも取得できない場合はエラー
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Could not decode BlobReference"
            )
        )
    }
    
    // エンコード用のメソッドを追加
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cid, forKey: .cid)
        try container.encode(mimeType, forKey: .mimeType)
    }
    
    // 手動で初期化するためのイニシャライザ
    public init(cid: String, mimeType: String) {
        self.cid = cid
        self.mimeType = mimeType
    }
    
    private enum CodingKeys: String, CodingKey {
        case cid, mimeType, ref
    }
    
    private enum RefCodingKeys: String, CodingKey {
        case link = "$link"
    }
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
        // まず、レスポンスデータを取得
        let dataResponse = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
            .validate()
            .serializingData()
            .response
        
        // レスポンスデータを確認
        if let data = dataResponse.data, let responseString = String(data: data, encoding: .utf8) {
            print("レスポンスボディ: \(responseString)")
            
            // JSONデータを解析
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("JSONデータ: \(json)")
                    
                    // blobフィールドを取得
                    if let blob = json["blob"] as? [String: Any] {
                        print("blob: \(blob)")
                        
                        // cidとmimeTypeを取得
                        if let cid = blob["cid"] as? String,
                           let mimeType = blob["mimeType"] as? String {
                            print("手動解析 - cid: \(cid), mimeType: \(mimeType)")
                            
                            // 手動でBlobReferenceを作成
                            let blobRef = BlobReference(cid: cid, mimeType: mimeType)
                            return UploadBlobResponse(blob: blobRef)
                        }
                    }
                }
            } catch {
                print("JSONデコードエラー: \(error)")
            }
        }
        
        // 通常のデコード処理を試す
        let response = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
            .validate()
            .serializingDecodable(UploadBlobResponse.self)
            .response
        
        switch response.result {
        case .success(let value):
            print("画像アップロード成功: \(value)")

            // CIDの形式を確認
            print("CIDの形式: \(value.blob.cid)")
            print("CIDの長さ: \(value.blob.cid.count)")
            print("CIDのプレフィックス: \(value.blob.cid.prefix(4))")

            // CIDがbase32またはbase58btcエンコードされているか確認
            if value.blob.cid.hasPrefix("bafy") || value.blob.cid.hasPrefix("bafk") {
                print("CIDは正しい形式です")
            } else {
                print("警告: CIDがbase32またはbase58btcエンコードされていない可能性があります")
                print("CID全体: \(value.blob.cid)")
            }

            return value
        case .failure(let error):
            print("画像アップロード失敗")
            print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
            print("ステータスコード: \(response.response?.statusCode ?? 0)")
            print("エラー: \(error)")
            
            // レスポンスデータを出力
            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                print("レスポンスボディ: \(responseString)")
                
                // レスポンスデータを手動でデコードしてみる
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("JSONデータ: \(json)")
                        
                        // blobフィールドを取得
                        if let blob = json["blob"] as? [String: Any] {
                            print("blob: \(blob)")
                            
                            // cidとmimeTypeを取得
                            if let cid = blob["cid"] as? String,
                               let mimeType = blob["mimeType"] as? String {
                                print("手動解析 - cid: \(cid), mimeType: \(mimeType)")
                                
                                // 手動でBlobReferenceを作成
                                let blobRef = BlobReference(cid: cid, mimeType: mimeType)
                                return UploadBlobResponse(blob: blobRef)
                            }
                        }
                    }
                } catch {
                    print("JSONデコードエラー: \(error)")
                }
            }
            
            throw error
        }
    } catch {
        throw error
    }
}
