import Foundation

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
