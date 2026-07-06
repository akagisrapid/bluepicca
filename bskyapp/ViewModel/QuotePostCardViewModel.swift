import Foundation
import PhotosUI
import SwiftUI

class QuotePostCardViewModel: PostComposerViewModel {
  let quotedPost: Post

  init(quotedPost: Post) {
    self.quotedPost = quotedPost
    super.init()
    // 引用は本文が空でも投稿できるため、初期状態を有効にする
    isTextValid = true
  }

  /// 引用投稿は本文が空でも許容するため、上限文字数のみで判定する。
  override func checkTextCount() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isTextValid = self.text.count <= self.maxTextCount
    }
  }

  func postQuote() async throws {
    guard let quotedUri = quotedPost.uri, let quotedCid = quotedPost.cid else {
      await MainActor.run {
        errorMessage = String(localized: "引用に必要な情報が不足しています")
        isPostFailed = true
      }
      throw NSError(
        domain: "QuoteError", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "引用に必要な情報が不足しています"])
    }

    do {
      let uploadedImages = try await uploadSelectedImagesIfNeeded()

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
}
