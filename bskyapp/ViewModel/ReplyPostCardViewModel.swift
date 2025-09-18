//
//  ReplyPostCardViewModel.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation
import Alamofire
import SwiftUI
import PhotosUI

class ReplyPostCardViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isPostCompleted: Bool = false
    @Published var isPostFailed: Bool = false
    @Published var isTextValid: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedImages: [UIImage] = []
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    
    private let notification: NotificationItem
    var maxTextCount: Int = 300
    var maxImageCount: Int = 4
    
    init(notification: NotificationItem) {
        self.notification = notification
    }
    
    func postReply() async throws {
        do {
            var uploadedImages: [UploadedImage]? = nil
            
            // 画像がある場合はアップロード
            if !selectedImages.isEmpty {
                await MainActor.run {
                    isUploading = true
                    uploadProgress = 0.0
                }
                
                uploadedImages = []
                let totalImages = selectedImages.count
                
                for (index, image) in selectedImages.enumerated() {
                    guard let imageData = ImageCompressionHelper.compressImage(image) else {
                        await MainActor.run {
                            errorMessage = "画像[\(index + 1)]の圧縮に失敗しました"
                        }
                        continue
                    }
                    
                    if ImageCompressionHelper.isFileSizeExceeded(imageData) {
                        let fileSizeString = ImageCompressionHelper.formatFileSize(imageData.count)
                        await MainActor.run {
                            errorMessage = "画像[\(index + 1)]のファイルサイズが大きすぎます (\(fileSizeString))"
                        }
                        continue
                    }
                    
                    do {
                        await MainActor.run {
                            uploadProgress = Double(index) / Double(totalImages)
                        }
                        
                        let endPoint = "https://bsky.social/xrpc/"
                        let uploadBlobEndpoint = "com.atproto.repo.uploadBlob"
                        let urlString = endPoint + uploadBlobEndpoint
                        
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
                            let uploadedImage = UploadedImage(
                                blobReference: value.blob,
                                alt: "画像の説明",
                                imageData: imageData
                            )
                            uploadedImages?.append(uploadedImage)
                            
                            await MainActor.run {
                                uploadProgress = Double(index + 1) / Double(totalImages)
                            }
                        case .failure(let error):
                            print("画像[\(index)]のアップロード失敗: \(error)")
                        }
                    } catch {
                        print("画像[\(index)]のアップロード例外: \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    isUploading = false
                    uploadProgress = 1.0
                }
            }
            
            // リプライレコードを作成
            let session = try await SessionManager.shared.getSession()
            
            // リプライ情報を作成
            let replyRef: [String: Any] = [
                "root": [
                    "uri": notification.uri,
                    "cid": notification.cid
                ],
                "parent": [
                    "uri": notification.uri,
                    "cid": notification.cid
                ]
            ]
            
            var recordDict: [String: Any] = [
                "$type": "app.bsky.feed.post",
                "text": text,
                "createdAt": Date().ISO8601Format(),
                "reply": replyRef
            ]
            
            // 画像がある場合は埋め込み情報を追加
            if let uploadedImages = uploadedImages, !uploadedImages.isEmpty {
                var imagesArray: [[String: Any]] = []
                
                for uploadedImage in uploadedImages {
                    let imageDict: [String: Any] = [
                        "alt": uploadedImage.alt,
                        "image": [
                            "$type": "blob",
                            "ref": [
                                "$link": uploadedImage.blobReference.cid
                            ],
                            "mimeType": uploadedImage.blobReference.mimeType,
                            "size": uploadedImage.imageData.count
                        ]
                    ]
                    imagesArray.append(imageDict)
                }
                
                let embedDict: [String: Any] = [
                    "$type": "app.bsky.embed.images",
                    "images": imagesArray
                ]
                
                recordDict["embed"] = embedDict
            }
            
            let paramDict: [String: Any] = [
                "repo": session.did,
                "collection": "app.bsky.feed.post",
                "record": recordDict
            ]
            
            // APIリクエストを送信
            let endPoint = "https://bsky.social/xrpc/"
            let createRecord = "com.atproto.repo.createRecord"
            let urlString = endPoint + createRecord
            
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
            case .success(_):
                await MainActor.run {
                    isPostCompleted = true
                    text = ""
                    selectedImages = []
                    selectedPhotoItems = []
                }
            case .failure(let error):
                print("リプライ送信失敗: \(error)")
                if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                    print("レスポンスボディ: \(responseString)")
                }
                throw error
            }
            
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = error.localizedDescription
                isPostFailed = true
            }
            throw error
        }
    }
    
    func checkTextCount() {
        DispatchQueue.main.async {
            self.isTextValid = 0 < self.text.count && self.text.count <= self.maxTextCount
        }
    }
    
    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }
    
    func loadImage(from item: PhotosPickerItem) {
        Task {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                
                guard let imageData = data else {
                    return
                }
                
                guard let image = UIImage(data: imageData) else {
                    return
                }
                
                await MainActor.run {
                    if selectedImages.count < maxImageCount {
                        selectedImages.append(image)
                        objectWillChange.send()
                    } else {
                        errorMessage = "最大\(maxImageCount)枚まで選択できます"
                    }
                }
            } catch {
                print("画像の読み込みエラー: \(error.localizedDescription)")
            }
        }
    }
    
    func removeImage(at index: Int) {
        if index < selectedImages.count {
            selectedImages.remove(at: index)
            if index < selectedPhotoItems.count {
                selectedPhotoItems.remove(at: index)
            }
        }
    }
    
    func canAddMoreImages() -> Bool {
        return selectedImages.count < maxImageCount
    }
}
