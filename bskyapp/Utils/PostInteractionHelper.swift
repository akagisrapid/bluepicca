import Foundation

/// いいね・リポストの楽観的UI更新とサーバー同期を共通化するヘルパー
struct PostInteractionHelper {

  // MARK: - State Restoration

  /// 永続化された状態をPostオブジェクトに復元
  static func restorePersistedStates(for post: Post) {
    guard let postUri = post.uri else { return }

    if PostStateManager.shared.isLiked(postUri: postUri) {
      let likeUri = PostStateManager.shared.getLikeUri(postUri: postUri)
      post.viewer = Viewer(
        repost: post.viewer?.repost,
        like: likeUri,
        replyDisabled: post.viewer?.replyDisabled
      )
    }

    if PostStateManager.shared.isReposted(postUri: postUri) {
      let repostUri = PostStateManager.shared.getRepostUri(postUri: postUri)
      post.viewer = Viewer(
        repost: repostUri,
        like: post.viewer?.like,
        replyDisabled: post.viewer?.replyDisabled
      )
    }
  }

  // MARK: - Like

  @MainActor
  static func toggleLike(post: Post) async {
    guard let postUri = post.uri else { return }

    let isLiked = post.viewer?.like != nil

    if isLiked {
      guard let likeUri = post.viewer?.like else { return }

      let originalViewer = post.viewer
      let originalLikeCount = post.likeCount

      post.viewer = Viewer(
        repost: post.viewer?.repost,
        like: nil,
        replyDisabled: post.viewer?.replyDisabled
      )

      if let currentCount = post.likeCount, currentCount > 0 {
        post.likeCount = currentCount - 1
      }

      PostStateManager.shared.removeLiked(postUri: postUri)

      Task {
        do {
          try await InteractionService.shared.unlike(likeUri: likeUri)
        } catch {
          dlog("いいね取り消し失敗: \(error)")
          await MainActor.run {
            post.viewer = originalViewer
            post.likeCount = originalLikeCount
            PostStateManager.shared.setLiked(postUri: postUri, likeUri: likeUri)
          }
        }
      }
    } else {
      let originalViewer = post.viewer
      let originalLikeCount = post.likeCount
      let tempLikeUri = "pending_like_\(postUri)"

      post.viewer = Viewer(
        repost: post.viewer?.repost,
        like: tempLikeUri,
        replyDisabled: post.viewer?.replyDisabled
      )

      if let currentCount = post.likeCount {
        post.likeCount = currentCount + 1
      } else {
        post.likeCount = 1
      }

      PostStateManager.shared.setLiked(postUri: postUri, likeUri: tempLikeUri)

      Task {
        do {
          let newLikeUri = try await InteractionService.shared.like(post: post)

          await MainActor.run {
            if post.viewer?.like != nil {
              post.viewer = Viewer(
                repost: post.viewer?.repost,
                like: newLikeUri,
                replyDisabled: post.viewer?.replyDisabled
              )
              PostStateManager.shared.setLiked(postUri: postUri, likeUri: newLikeUri)
            }
          }
        } catch {
          dlog("いいね失敗: \(error)")
          await MainActor.run {
            post.viewer = originalViewer
            post.likeCount = originalLikeCount
            PostStateManager.shared.removeLiked(postUri: postUri)
          }
        }
      }
    }
  }

  // MARK: - Repost

  @MainActor
  static func toggleRepost(post: Post) async {
    guard let postUri = post.uri else { return }

    let isReposted = post.viewer?.repost != nil

    if isReposted {
      guard let repostUri = post.viewer?.repost else { return }

      let originalViewer = post.viewer
      let originalRepostCount = post.repostCount

      post.viewer = Viewer(
        repost: nil,
        like: post.viewer?.like,
        replyDisabled: post.viewer?.replyDisabled
      )

      if let currentCount = post.repostCount, currentCount > 0 {
        post.repostCount = currentCount - 1
      }

      PostStateManager.shared.removeReposted(postUri: postUri)

      Task {
        do {
          try await InteractionService.shared.unrepost(repostUri: repostUri)
        } catch {
          dlog("リポスト取り消し失敗: \(error)")
          await MainActor.run {
            post.viewer = originalViewer
            post.repostCount = originalRepostCount
            PostStateManager.shared.setReposted(postUri: postUri, repostUri: repostUri)
          }
        }
      }
    } else {
      let originalViewer = post.viewer
      let originalRepostCount = post.repostCount
      let tempRepostUri = "pending_repost_\(postUri)"

      post.viewer = Viewer(
        repost: tempRepostUri,
        like: post.viewer?.like,
        replyDisabled: post.viewer?.replyDisabled
      )

      if let currentCount = post.repostCount {
        post.repostCount = currentCount + 1
      } else {
        post.repostCount = 1
      }

      PostStateManager.shared.setReposted(postUri: postUri, repostUri: tempRepostUri)

      Task {
        do {
          let newRepostUri = try await InteractionService.shared.repost(post: post)

          await MainActor.run {
            if post.viewer?.repost != nil {
              post.viewer = Viewer(
                repost: newRepostUri,
                like: post.viewer?.like,
                replyDisabled: post.viewer?.replyDisabled
              )
              PostStateManager.shared.setReposted(postUri: postUri, repostUri: newRepostUri)
            }
          }
        } catch {
          dlog("リポスト失敗: \(error)")
          await MainActor.run {
            post.viewer = originalViewer
            post.repostCount = originalRepostCount
            PostStateManager.shared.removeReposted(postUri: postUri)
          }
        }
      }
    }
  }
}
