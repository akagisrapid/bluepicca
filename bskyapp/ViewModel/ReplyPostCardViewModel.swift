//
//  ReplyPostCardViewModel.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation
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

    private let notification: NotificationItem?
    private let post: Post?
    var maxTextCount: Int = 300
    var maxImageCount: Int = 4

    // NotificationItem用のイニシャライザー
    init(notification: NotificationItem) {
        self.notification = notification
        self.post = nil
    }

    // Post用のイニシャライザー
    init(post: Post) {
        self.notification = nil
        self.post = post
    }

    func postReply() async throws {
        do {
            // Resolve parent URI and CID
            let parentUri: String
            let parentCid: String

            if let notification = notification {
                parentUri = notification.uri
                parentCid = notification.cid
            } else if let post = post, let uri = post.uri, let cid = post.cid {
                parentUri = uri
                parentCid = cid
            } else {
                await MainActor.run {
                    errorMessage = "リプライに必要な情報が不足しています"
                    isPostFailed = true
                }
                throw NSError(domain: "ReplyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "リプライに必要な情報が不足しています"])
            }

            // Upload images if any
            var uploadedImages: [UploadedImage]? = nil

            if !selectedImages.isEmpty {
                await MainActor.run {
                    isUploading = true
                    uploadProgress = 0.0
                }

                let imagesToUpload = selectedImages.map { ImageToUpload(image: $0, alt: "画像の説明") }

                uploadedImages = try await PostCreationService.shared.uploadImages(imagesToUpload) { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress = progress
                    }
                }

                await MainActor.run {
                    isUploading = false
                    uploadProgress = 1.0
                }

                if uploadedImages?.isEmpty ?? true {
                    uploadedImages = nil
                }
            }

            // Create reply
            try await PostCreationService.shared.createReply(
                text: text,
                images: uploadedImages,
                parentUri: parentUri,
                parentCid: parentCid
            )

            await MainActor.run {
                isPostCompleted = true
                text = ""
                selectedImages = []
                selectedPhotoItems = []
                NotificationCenter.default.post(name: .postCreated, object: nil)
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = error.userFacingMessage
                isPostFailed = true
            }
            throw error
        }
    }

    func checkTextCount() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isTextValid = 0 < self.text.count && self.text.count <= self.maxTextCount
        }
    }

    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }

    func loadImage(from item: PhotosPickerItem) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await item.loadTransferable(type: Data.self)

                guard let imageData = data else { return }
                guard let image = UIImage(data: imageData) else { return }

                await MainActor.run {
                    if self.selectedImages.count < self.maxImageCount {
                        self.selectedImages.append(image)
                        self.objectWillChange.send()
                    } else {
                        self.errorMessage = "最大\(self.maxImageCount)枚まで選択できます"
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
