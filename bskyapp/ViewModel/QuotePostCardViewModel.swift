import Foundation
import PhotosUI
import SwiftUI

class QuotePostCardViewModel: ObservableObject {
  @Published var text: String = ""
  @Published var isPostCompleted: Bool = false
  @Published var isPostFailed: Bool = false
  @Published var isTextValid: Bool = true
  @Published var errorMessage: String = ""
  @Published var selectedImages: [IdentifiableImage] = []
  @Published var selectedPhotoItems: [PhotosPickerItem] = []
  @Published var isUploading: Bool = false
  @Published var uploadProgress: Double = 0.0

  let quotedPost: Post
  var maxTextCount: Int = 300
  var maxImageCount: Int = 4

  init(quotedPost: Post) {
    self.quotedPost = quotedPost
  }

  func postQuote() async throws {
    guard let quotedUri = quotedPost.uri, let quotedCid = quotedPost.cid else {
      await MainActor.run {
        errorMessage = "引用に必要な情報が不足しています"
        isPostFailed = true
      }
      throw NSError(
        domain: "QuoteError", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "引用に必要な情報が不足しています"])
    }

    do {
      var uploadedImages: [UploadedImage]? = nil

      if !selectedImages.isEmpty {
        await MainActor.run {
          isUploading = true
          uploadProgress = 0.0
        }

        let imagesToUpload = selectedImages.map { ImageToUpload(image: $0.image, alt: "画像の説明") }

        uploadedImages = try await PostCreationService.shared.uploadImages(imagesToUpload) {
          [weak self] progress in
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

      try await PostCreationService.shared.createQuotePost(
        text: text,
        images: uploadedImages,
        quotedUri: quotedUri,
        quotedCid: quotedCid
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
      self.isTextValid = self.text.count <= self.maxTextCount
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
            self.selectedImages.append(IdentifiableImage(image: image))
            self.objectWillChange.send()
          } else {
            self.errorMessage = "最大\(self.maxImageCount)枚まで選択できます"
          }
        }
      } catch {
        dlog("画像の読み込みエラー: \(error.localizedDescription)")
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
