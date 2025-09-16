import Foundation
import Alamofire
import SwiftUI
import PhotosUI

class PostCardViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var isPostCompleted: Bool = false
    @Published var isPostFailed: Bool = false
    @Published var isTextValid: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedImages: [UIImage] = []
    @Published var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet {
            print("selectedPhotoItems didSet: \(selectedPhotoItems.count)個")
        }
    }
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    
    var maxTextCount: Int = 300
    var maxImageCount: Int = 4
    
    init(text: String) {
        self.text = text
    }
    
    func postText() async throws {
        do {
            var uploadedImages: [UploadedImage]? = nil
            
            print("PostCardViewModel.postText() - 画像数: \(selectedImages.count)")
            
            if !selectedImages.isEmpty {
                await MainActor.run {
                    isUploading = true
                    uploadProgress = 0.0
                }
                
                uploadedImages = []
                let totalImages = selectedImages.count
                
                for (index, image) in selectedImages.enumerated() {
                    print("画像[\(index)]の処理を開始")
                    
                    // 画像圧縮ヘルパーを使用してファイルサイズ制限内に圧縮
                    guard let imageData = ImageCompressionHelper.compressImage(image) else {
                        print("画像[\(index)]の圧縮に失敗")
                        await MainActor.run {
                            errorMessage = "画像[\(index + 1)]の圧縮に失敗しました"
                        }
                        continue
                    }
                    
                    let fileSizeString = ImageCompressionHelper.formatFileSize(imageData.count)
                    print("画像[\(index)]のサイズ: \(imageData.count)バイト (\(fileSizeString))")
                    
                    // ファイルサイズ制限チェック
                    if ImageCompressionHelper.isFileSizeExceeded(imageData) {
                        print("警告: 画像[\(index)]がファイルサイズ制限を超えています: \(fileSizeString)")
                        await MainActor.run {
                            errorMessage = "画像[\(index + 1)]のファイルサイズが大きすぎます (\(fileSizeString))"
                        }
                        continue
                    }
                    
                    do {
                        print("画像[\(index)]のアップロード開始: サイズ=\(imageData.count)バイト")
                        
                        // アップロード前の進捗更新
                        await MainActor.run {
                            uploadProgress = Double(index) / Double(totalImages)
                        }
                        
                        // 直接APIを呼び出す
                        let endPoint = "https://bsky.social/xrpc/"
                        let uploadBlobEndpoint = "com.atproto.repo.uploadBlob"
                        let urlString = endPoint + uploadBlobEndpoint
                        
                        let session = try await SessionManager.shared.getSession()
                        let headers: HTTPHeaders = [
                            "Content-Type": "image/jpeg",
                            "Authorization": "Bearer \(session.accessJwt)"
                        ]
                        
                        print("画像[\(index)]のアップロードリクエスト送信")
                        let response = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
                            .validate()
                            .serializingDecodable(UploadBlobResponse.self)
                            .response
                        
                        switch response.result {
                        case .success(let value):
                            print("画像[\(index)]のアップロード成功: cid=\(value.blob.cid)")
                            
                            let uploadedImage = UploadedImage(
                                blobReference: value.blob,
                                alt: "画像の説明",
                                imageData: imageData
                            )
                            uploadedImages?.append(uploadedImage)
                            
                            // アップロード後の進捗更新
                            await MainActor.run {
                                uploadProgress = Double(index + 1) / Double(totalImages)
                            }
                        case .failure(let error):
                            print("画像[\(index)]のアップロード失敗: \(error)")
                            print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
                            print("ステータスコード: \(response.response?.statusCode ?? 0)")
                            
                            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                                print("レスポンスボディ: \(responseString)")
                            }
                            
                            // エラーが発生しても処理を続行
                        }
                    } catch {
                        print("画像[\(index)]のアップロード例外: \(error.localizedDescription)")
                        // エラーが発生しても処理を続行
                    }
                }
                
                await MainActor.run {
                    isUploading = false
                    uploadProgress = 1.0
                }
                
                print("アップロードされた画像数: \(uploadedImages?.count ?? 0)")

                // 画像がアップロードされたかどうかを確認
                if let images = uploadedImages, !images.isEmpty {
                    print("アップロードされた画像情報:")
                    for (index, image) in images.enumerated() {
                        print("画像[\(index)] - cid: \(image.blobReference.cid), mimeType: \(image.blobReference.mimeType)")
                    }
                } else {
                    print("画像のアップロードに失敗したため、画像なしのポストとして処理します")
                    // 画像なしのポストとして処理
                    let param = try await makeCreateRecordRequest(text: text)
                    try await createRecord(param: param)
                    return
                }
            }
            
            // 画像埋め込みを含むポストを作成
            if !selectedImages.isEmpty {
                print("画像埋め込みを含むポストを作成します")

                // 画像埋め込み用の辞書を作成
                var imagesArray: [[String: Any]] = []

                // 既にアップロードされた画像を使用
                if let uploadedImages = uploadedImages {
                    for (index, uploadedImage) in uploadedImages.enumerated() {
                        print("画像[\(index)]のblob refを使用: cid=\(uploadedImage.blobReference.cid)")

                        // 画像情報を辞書に追加（blob refの正しい形式）
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
                }
                
                // 画像埋め込み用の辞書を作成
                let embedDict: [String: Any] = [
                    "$type": "app.bsky.embed.images",
                    "images": imagesArray
                ]
                
                // ポストレコードを作成
                let recordDict: [String: Any] = [
                    "$type": "app.bsky.feed.post",
                    "text": text,
                    "createdAt": Date().ISO8601Format(),
                    "embed": embedDict
                ]
                
                // リクエストパラメータを作成
                let session = try await SessionManager.shared.getSession()
                let paramDict: [String: Any] = [
                    "repo": session.did,
                    "collection": "app.bsky.feed.post",
                    "record": recordDict
                ]
                
                print("送信するパラメータ: \(paramDict)")

                // 画像埋め込み部分を詳細に確認
                if let embed = paramDict["record"] as? [String: Any],
                   let embedDict = embed["embed"] as? [String: Any],
                   let images = embedDict["images"] as? [[String: Any]],
                   let firstImage = images.first,
                   let image = firstImage["image"] as? [String: Any] {
                    print("最初の画像のblob ref: \(image)")
                    if let ref = image["ref"] as? [String: Any],
                       let link = ref["$link"] as? String {
                        print("CID: \(link)")
                        print("CIDプレフィックス: \(link.prefix(4))")
                        print("CID長さ: \(link.count)")
                    }
                }
                
                // 直接APIを呼び出す
                let endPoint = "https://bsky.social/xrpc/"
                let createRecord = "com.atproto.repo.createRecord"
                let urlString = endPoint + createRecord
                
                let headers: HTTPHeaders = [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(session.accessJwt)"
                ]
                
                // JSONデータに変換
                let jsonData = try JSONSerialization.data(withJSONObject: paramDict, options: [])
                
                // URLRequestを作成
                var request = URLRequest(url: URL(string: urlString)!)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                
                // ヘッダーを設定
                headers.forEach { header in
                    request.setValue(header.value, forHTTPHeaderField: header.name)
                }
                
                // リクエストを送信
                let response = await AF.request(request)
                    .validate()
                    .serializingDecodable(CreateRecordResponse.self)
                    .response
                
                switch response.result {
                case .success(let value):
                    print("ポスト成功: \(value)")
                case .failure(let error):
                    print("ポスト失敗: \(error)")
                    print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
                    print("ステータスコード: \(response.response?.statusCode ?? 0)")
                    
                    if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                        print("レスポンスボディ: \(responseString)")
                    }
                    
                    throw error
                }
            } else {
                // 通常のポスト（画像なし）
                print("通常のポストを作成します")
                print("ポスト作成リクエスト開始")
                let param = try await makeCreateRecordRequest(text: text)
                print("ポスト送信開始")
                try await createRecord(param: param)
                print("ポスト送信完了")
            }
        } catch {
            // Update UI properties on the main thread
            await MainActor.run {
                isUploading = false
                errorMessage = error.localizedDescription
                if let afError = error as? Alamofire.AFError, 
                   let statusCode = afError.responseCode,
                   statusCode == 429 {
                    errorMessage = "投稿回数制限に達しました。しばらく待ってから再度お試しください。"
                    // Clear session to force a new one next time
                    SessionManager.shared.clearSession()
                }
            }
            throw error
        }
    }
    func checkTextCount() {
        // Ensure we're on the main thread when updating published properties
        DispatchQueue.main.async {
            self.isTextValid = 0 < self.text.count && self.text.count <= self.maxTextCount
        }
    }
    
    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }
    
    func loadImage(from item: PhotosPickerItem) {
        Task {
            print("画像の読み込み開始: \(item.itemIdentifier ?? "unknown")")
            do {
                // 画像データを非同期で読み込む
                let data = try await item.loadTransferable(type: Data.self)
                
                guard let imageData = data else {
                    print("画像データの読み込みに失敗")
                    return
                }
                
                print("画像データの読み込み成功: \(imageData.count)バイト")
                
                guard let image = UIImage(data: imageData) else {
                    print("UIImageへの変換に失敗")
                    return
                }
                
                print("UIImageへの変換成功: \(image.size.width) x \(image.size.height)")
                
                // 画像サイズをチェックして圧縮が必要かどうか確認
                let originalSize = imageData.count
                let originalSizeString = ImageCompressionHelper.formatFileSize(originalSize)
                print("元の画像サイズ: \(originalSizeString)")
                
                // 圧縮後のサイズを事前にチェック
                if let compressedData = ImageCompressionHelper.compressImage(image) {
                    let compressedSize = compressedData.count
                    let compressedSizeString = ImageCompressionHelper.formatFileSize(compressedSize)
                    
                    if originalSize > ImageCompressionHelper.maxFileSizeBytes {
                        print("画像が圧縮されます: \(originalSizeString) → \(compressedSizeString)")
                    }
                    
                    // UIの更新はメインスレッドで行う
                    await MainActor.run {
                        if selectedImages.count < maxImageCount {
                            // 既存の画像に追加
                            selectedImages.append(image)
                            print("画像が追加されました。現在の画像数: \(selectedImages.count)")
                            
                            // 圧縮が必要だった場合はメッセージを表示
                            if originalSize > ImageCompressionHelper.maxFileSizeBytes {
                                errorMessage = "画像が大きいため、投稿時に圧縮されます (\(originalSizeString) → \(compressedSizeString))"
                            }
                            
                            // 画像が追加されたことを通知するために、オブジェクトを更新
                            objectWillChange.send()
                        } else {
                            print("最大画像数に達しているため追加できません")
                            errorMessage = "最大\(maxImageCount)枚まで選択できます"
                        }
                    }
                } else {
                    print("画像の圧縮テストに失敗")
                    await MainActor.run {
                        errorMessage = "この画像は使用できません"
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
