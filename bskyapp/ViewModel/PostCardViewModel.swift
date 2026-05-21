import Alamofire
import Foundation
import PhotosUI
import SwiftUI

class PostCardViewModel: ObservableObject {
  @Published var text: String = ""
  @Published var isPostCompleted: Bool = false
  @Published var isPostFailed: Bool = false
  @Published var isTextValid: Bool = false
  @Published var errorMessage: String = ""
  @Published var selectedImages: [UIImage] = []
  @Published var selectedPhotoItems: [PhotosPickerItem] = [] {
    didSet {
      dlog("selectedPhotoItems didSet: \(selectedPhotoItems.count)個")
    }
  }
  @Published var isUploading: Bool = false
  @Published var uploadProgress: Double = 0.0
  @Published var selectedThreadgateRules: Set<ThreadgateRule> = []
  @Published var replyDisabled: Bool = false
  @Published var quotingDisabled: Bool = false

  var maxTextCount: Int = 300
  var maxImageCount: Int = 4

  init(text: String) {
    self.text = text
  }

  func postText() async throws {
    do {
      var uploadedImages: [UploadedImage]? = nil

      if !selectedImages.isEmpty {
        await MainActor.run {
          isUploading = true
          uploadProgress = 0.0
        }

        let imagesToUpload = selectedImages.map { ImageToUpload(image: $0, alt: "画像の説明") }

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

      try await PostCreationService.shared.createPost(
        text: text,
        images: uploadedImages,
        threadgateRules: selectedThreadgateRules,
        replyDisabled: replyDisabled,
        quotingDisabled: quotingDisabled)
      NotificationCenter.default.post(name: .postCreated, object: nil)
    } catch {
      await MainActor.run {
        isUploading = false
        errorMessage = error.localizedDescription
        if let afError = error as? AFError,
          let statusCode = afError.responseCode,
          statusCode == 429
        {
          errorMessage = "投稿回数制限に達しました。しばらく待ってから再度お試しください。"
          SessionManager.shared.clearSession()
        }
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

        let originalSize = imageData.count

        if let compressedData = ImageCompressionHelper.compressImage(image) {
          let compressedSizeString = ImageCompressionHelper.formatFileSize(compressedData.count)
          let originalSizeString = ImageCompressionHelper.formatFileSize(originalSize)

          await MainActor.run {
            if selectedImages.count < maxImageCount {
              selectedImages.append(image)
              objectWillChange.send()

              if originalSize > ImageCompressionHelper.maxFileSizeBytes {
                errorMessage =
                  "画像が大きいため、投稿時に圧縮されます (\(originalSizeString) → \(compressedSizeString))"
              }
            } else {
              errorMessage = "最大\(maxImageCount)枚まで選択できます"
            }
          }
        } else {
          await MainActor.run {
            errorMessage = "この画像は使用できません"
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
