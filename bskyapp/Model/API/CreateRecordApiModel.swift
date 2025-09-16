import Foundation
import Alamofire

struct CreateRecordPostItem: Codable {
    let text: String
    let createdAt: String?
    let embed: Embed?
    
    private enum CodingKeys: String, CodingKey {
        case text, createdAt, embed
    }
    
    init(text: String, createdAt: String?, embed: Embed?) {
        self.text = text
        self.createdAt = createdAt
        self.embed = embed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        // embedはJSONオブジェクトとして扱う
        if container.contains(.embed) {
            let embedData = try container.decode(Data.self, forKey: .embed)
            embed = try JSONDecoder().decode(Embed.self, from: embedData)
        } else {
            embed = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(embed, forKey: .embed)
    }
}

struct CreateRecordRequest: Codable{
    var repo: String
    let collection: String
    let rkey: String?
    let validate: Bool?
    let record: CreateRecordPostItem
    let swapCommit: String?
}

struct EmbedImages: Codable {
    let type: String = "app.bsky.embed.images"
    let images: [EmbedImage]
}

struct EmbedImage: Codable {
    let alt: String
    let image: ImageReference
}

struct ImageReference: Codable {
    let cid: String
    let mimeType: String
}

func makeCreateRecordRequest(text: String, images: [UploadedImage]? = nil) async throws -> CreateRecordRequest {
    var embedJson: [String: Any]? = nil
    
    if let images = images, !images.isEmpty {
        print("画像が選択されています: \(images.count)枚")
        
        // 画像情報をログ出力
        for (index, image) in images.enumerated() {
            print("画像[\(index)] - cid: \(image.blobReference.cid), mimeType: \(image.blobReference.mimeType), サイズ: \(image.imageData.count)バイト")
        }
        
        // Blueskyの画像埋め込みAPIに合わせた構造を作成
        let imagesArray = images.map { image -> [String: Any] in
            return [
                "alt": image.alt,
                "image": [
                    "$type": "blob",
                    "ref": [
                        "$link": image.blobReference.cid
                    ],
                    "mimeType": image.blobReference.mimeType
                ]
            ]
        }
        
        embedJson = [
            "$type": "app.bsky.embed.images",
            "images": imagesArray
        ]
        
        print("画像埋め込み用JSON構造を作成: \(String(describing: embedJson))")
    } else {
        print("画像が選択されていません")
    }
    
    // 画像埋め込みがある場合は、JSONをそのまま使用
    var recordDict: [String: Any] = [
        "text": text,
        "createdAt": Date().ISO8601Format()
    ]
    
    if let embedJson = embedJson {
        recordDict["embed"] = embedJson
    }
    
    print("ポストレコード: \(recordDict)")
    
    // 直接CreateRecordPostItemを作成
    let embed: Embed? = embedJson != nil ? Embed(type: "app.bsky.embed.images", images: nil, external: nil, record: nil) : nil
    let record = CreateRecordPostItem(text: text, createdAt: Date().ISO8601Format(), embed: embed)
    let session = try await SessionManager.shared.getSession()
    let collection = "app.bsky.feed.post"
    return CreateRecordRequest(
        repo: session.did,
        collection: collection,
        rkey: nil,
        validate : nil,
        record: record,
        swapCommit: nil)
}

struct UploadedImage {
    let blobReference: BlobReference
    let alt: String
    let imageData: Data
}


/// 投稿レスポンス
struct CreateRecordResponse: Codable {
    let uri: String?
    let cid: String?
}
