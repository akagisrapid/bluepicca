import Foundation
import Alamofire

class PostCreationService {
    static let shared = PostCreationService()

    private let endPoint = "https://bsky.social/xrpc/"

    private init() {}

    // MARK: - Image Upload

    func uploadImages(
        _ images: [ImageToUpload],
        onProgress: @escaping (Double) -> Void
    ) async throws -> [UploadedImage] {
        var uploadedImages: [UploadedImage] = []
        let totalImages = images.count

        for (index, imageToUpload) in images.enumerated() {
            onProgress(Double(index) / Double(totalImages))

            guard let imageData = ImageCompressionHelper.compressImage(imageToUpload.image) else {
                print("画像[\(index)]の圧縮に失敗")
                continue
            }

            if ImageCompressionHelper.isFileSizeExceeded(imageData) {
                let fileSizeString = ImageCompressionHelper.formatFileSize(imageData.count)
                print("画像[\(index)]がファイルサイズ制限を超えています: \(fileSizeString)")
                continue
            }

            do {
                let blobResponse = try await uploadBlob(imageData: imageData)

                let uploadedImage = UploadedImage(
                    blobReference: blobResponse.blob,
                    alt: imageToUpload.alt,
                    imageData: imageData
                )
                uploadedImages.append(uploadedImage)

                onProgress(Double(index + 1) / Double(totalImages))
            } catch {
                print("画像[\(index)]のアップロード失敗: \(error)")
            }
        }

        return uploadedImages
    }

    // MARK: - Post Creation

    func createPost(text: String, images: [UploadedImage]?) async throws {
        let session = try await SessionManager.shared.getSession()

        var recordDict: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": Date().ISO8601Format()
        ]

        if let images = images, !images.isEmpty {
            recordDict["embed"] = buildImageEmbed(images)
        }

        let paramDict: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": recordDict
        ]

        try await sendCreateRecord(paramDict: paramDict, session: session)
    }

    // MARK: - Reply Creation

    func createReply(
        text: String,
        images: [UploadedImage]?,
        parentUri: String,
        parentCid: String
    ) async throws {
        let session = try await SessionManager.shared.getSession()

        let replyRef: [String: Any] = [
            "root": ["uri": parentUri, "cid": parentCid],
            "parent": ["uri": parentUri, "cid": parentCid]
        ]

        var recordDict: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": Date().ISO8601Format(),
            "reply": replyRef
        ]

        if let images = images, !images.isEmpty {
            recordDict["embed"] = buildImageEmbed(images)
        }

        let paramDict: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": recordDict
        ]

        try await sendCreateRecord(paramDict: paramDict, session: session)
    }

    // MARK: - Private Helpers

    private func uploadBlob(imageData: Data) async throws -> UploadBlobResponse {
        let urlString = endPoint + "com.atproto.repo.uploadBlob"
        let session = try await SessionManager.shared.getSession()

        let headers: HTTPHeaders = [
            "Content-Type": "image/jpeg",
            "Authorization": "Bearer \(session.accessJwt)"
        ]

        let response = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
            .validate()
            .serializingDecodable(UploadBlobResponse.self)
            .response

        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    private func buildImageEmbed(_ images: [UploadedImage]) -> [String: Any] {
        let imagesArray: [[String: Any]] = images.map { image in
            [
                "alt": image.alt,
                "image": [
                    "$type": "blob",
                    "ref": ["$link": image.blobReference.cid],
                    "mimeType": image.blobReference.mimeType,
                    "size": image.imageData.count
                ]
            ]
        }

        return [
            "$type": "app.bsky.embed.images",
            "images": imagesArray
        ]
    }

    private func sendCreateRecord(paramDict: [String: Any], session: CreateSessionResponse) async throws {
        let urlString = endPoint + "com.atproto.repo.createRecord"

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: paramDict, options: [])

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData

        headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        let response = await AF.request(request)
            .validate()
            .serializingDecodable(CreateRecordResponse.self)
            .response

        switch response.result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

/// Input model for images to be uploaded
struct ImageToUpload {
    let image: UIImage
    let alt: String
}
