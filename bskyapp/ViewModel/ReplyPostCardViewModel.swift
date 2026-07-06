//
//  ReplyPostCardViewModel.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation
import PhotosUI
import SwiftUI

class ReplyPostCardViewModel: PostComposerViewModel {
  private let notification: NotificationItem?
  private let post: Post?

  // NotificationItem用のイニシャライザー
  init(notification: NotificationItem) {
    self.notification = notification
    self.post = nil
    super.init()
  }

  // Post用のイニシャライザー
  init(post: Post) {
    self.notification = nil
    self.post = post
    super.init()
  }

  func postReply() async throws {
    do {
      // 返信先の URI / CID を解決
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
          errorMessage = String(localized: "リプライに必要な情報が不足しています")
          isPostFailed = true
        }
        throw NSError(
          domain: "ReplyError", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "リプライに必要な情報が不足しています"])
      }

      let uploadedImages = try await uploadSelectedImagesIfNeeded()

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
}
