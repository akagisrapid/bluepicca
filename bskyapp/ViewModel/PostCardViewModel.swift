import Alamofire
import Foundation
import PhotosUI
import SwiftUI

class PostCardViewModel: PostComposerViewModel {
  @Published var selectedThreadgateRules: Set<ThreadgateRule> = []
  @Published var replyDisabled: Bool = false
  @Published var quotingDisabled: Bool = false

  init(text: String) {
    super.init()
    self.text = text
  }

  func postText() async throws {
    do {
      let uploadedImages = try await uploadSelectedImagesIfNeeded()

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
          errorMessage = String(localized: "投稿回数制限に達しました。しばらく待ってから再度お試しください。")
          SessionManager.shared.clearSession()
        }
      }
      throw error
    }
  }

  /// 新規投稿では画像を圧縮し、サイズが大きい場合は圧縮予告メッセージを表示する。
  override func loadImage(from item: PhotosPickerItem) {
    Task { [weak self] in
      guard let self else { return }
      do {
        let data = try await item.loadTransferable(type: Data.self)
        guard let imageData = data, let image = UIImage(data: imageData) else { return }
        let originalSize = imageData.count

        guard let compressedData = ImageCompressionHelper.compressImage(image) else {
          await MainActor.run {
            self.errorMessage = String(localized: "この画像は使用できません")
          }
          return
        }
        let compressedSizeString = ImageCompressionHelper.formatFileSize(compressedData.count)
        let originalSizeString = ImageCompressionHelper.formatFileSize(originalSize)

        await MainActor.run {
          if self.appendImageIfPossible(image) {
            self.checkTextCount()
            if originalSize > ImageCompressionHelper.maxFileSizeBytes {
              self.errorMessage = String(
                localized: "画像が大きいため、投稿時に圧縮されます (\(originalSizeString) → \(compressedSizeString))"
              )
            }
          }
        }
      } catch {
        dlog("画像の読み込みエラー: \(error.localizedDescription)")
      }
    }
  }
}
