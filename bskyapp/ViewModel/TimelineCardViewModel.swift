import Foundation

class TimelineCardViewModel: ObservableObject {
  @Published var post: Post
  @Published var reason: Reason?
  @Published var reply: Reply?
  @Published var isLiking: Bool = false
  @Published var isReposting: Bool = false

  init(post: Post, reason: Reason? = nil, reply: Reply? = nil) {
    self.post = post
    self.reason = reason
    self.reply = reply

    // 永続化された状態を復元
    restorePersistedStates()
  }
  var authorName: String {
    post.author?.displayName ?? ""
  }
  var text: String {
    post.record?.text ?? ""
  }
  var likeCount: Int {
    post.likeCount ?? 0
  }
  var postedTimeRelative: String {
    let postTime = post.record?.createdAt?.parseToDateRemovingMilliseconds
    return postTime?.relativeDateString ?? ""
  }

  // リポスト情報関連のプロパティ
  var isRepost: Bool {
    return reason != nil
  }

  var repostAuthorName: String {
    return reason?.by.displayName ?? reason?.by.handle ?? ""
  }

  var repostAuthorHandle: String {
    return reason?.by.handle ?? ""
  }

  // MARK: - リプライ情報関連のプロパティ

  /// リプライかどうかを判定
  var isReply: Bool {
    return reply != nil
  }

  /// リプライ先の作者名
  var replyTargetAuthorName: String {
    return reply?.parent?.author?.displayName ?? reply?.parent?.author?.handle ?? ""
  }

  /// リプライ先の作者ハンドル
  var replyTargetAuthorHandle: String {
    return reply?.parent?.author?.handle ?? ""
  }

  /// リプライ先のテキスト（プレビュー用）
  var replyTargetText: String {
    let text = reply?.parent?.record?.text ?? ""
    // 長すぎる場合は省略
    if text.count > 50 {
      return String(text.prefix(50)) + "..."
    }
    return text
  }

  // MARK: - 永続化された状態の管理

  /// 永続化された状態を復元
  private func restorePersistedStates() {
    guard let postUri = post.uri else { return }

    // 永続化されたいいね状態を復元
    if PostStateManager.shared.isLiked(postUri: postUri) {
      let likeUri = PostStateManager.shared.getLikeUri(postUri: postUri)
      // Viewerオブジェクトを更新（存在しない場合は作成）
      if post.viewer == nil {
        post.viewer = Viewer(repost: nil, like: likeUri, replyDisabled: nil)
      } else {
        // 既存のViewerを更新（Viewerは構造体なので新しいインスタンスを作成）
        post.viewer = Viewer(
          repost: post.viewer?.repost,
          like: likeUri,
          replyDisabled: post.viewer?.replyDisabled
        )
      }
    }

    // 永続化されたリポスト状態を復元
    if PostStateManager.shared.isReposted(postUri: postUri) {
      let repostUri = PostStateManager.shared.getRepostUri(postUri: postUri)
      // Viewerオブジェクトを更新（存在しない場合は作成）
      if post.viewer == nil {
        post.viewer = Viewer(repost: repostUri, like: nil, replyDisabled: nil)
      } else {
        // 既存のViewerを更新
        post.viewer = Viewer(
          repost: repostUri,
          like: post.viewer?.like,
          replyDisabled: post.viewer?.replyDisabled
        )
      }
    }
  }

  // MARK: - いいね機能

  /// いいね状態を取得
  var isLiked: Bool {
    return post.viewer?.like != nil
  }

  /// いいね処理（バッチ処理対応）
  /// いいね処理（バッチ処理対応）
  @MainActor
  func toggleLike() async {
    guard let postUri = post.uri else {
      print("いいねに必要な情報（uri）が不足しています")
      return
    }

    isLiking = true

    if isLiked {
      // いいね取り消し
      if let likeUri = post.viewer?.like {

        // ローカル状態を即座に更新（楽観的UI）
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

        // サーバー通信
        Task {
          do {
            try await InteractionService.shared.unlike(likeUri: likeUri)
            print("いいね取り消し成功")
          } catch {
            print("いいね取り消し失敗: \(error)")
            // ロールバック
            await MainActor.run {
              post.viewer = originalViewer
              post.likeCount = originalLikeCount
              PostStateManager.shared.setLiked(postUri: postUri, likeUri: likeUri)
            }
          }
        }
      }
    } else {
      // いいね

      // ローカル状態を即座に更新（楽観的UI）
      let originalViewer = post.viewer
      let originalLikeCount = post.likeCount

      // 仮のURI
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

      // サーバー通信
      Task {
        do {
          let newLikeUri = try await InteractionService.shared.like(post: post)
          print("いいね成功: \(newLikeUri)")

          // 正しいURIで更新
          await MainActor.run {
            // ユーザーが連打していないか確認（現在のstateがまだLike状態か）
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
          print("いいね失敗: \(error)")
          // ロールバック
          await MainActor.run {
            post.viewer = originalViewer
            post.likeCount = originalLikeCount
            PostStateManager.shared.removeLiked(postUri: postUri)
          }
        }
      }
    }

    isLiking = false
  }

  // MARK: - リポスト機能

  /// リポスト状態を取得
  var isReposted: Bool {
    return post.viewer?.repost != nil
  }

  /// リポスト数を取得
  var repostCount: Int {
    return post.repostCount ?? 0
  }

  /// リポスト処理（バッチ処理対応）
  @MainActor
  func toggleRepost() async {
    guard let postUri = post.uri else {
      print("リポストに必要な情報（uri）が不足しています")
      return
    }

    isReposting = true

    if isReposted {
      // リポスト取り消し
      if let repostUri = post.viewer?.repost {

        // ローカル状態を即座に更新
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

        // サーバー通信
        Task {
          do {
            try await InteractionService.shared.unrepost(repostUri: repostUri)
            print("リポスト取り消し成功")
          } catch {
            print("リポスト取り消し失敗: \(error)")
            // ロールバック
            await MainActor.run {
              post.viewer = originalViewer
              post.repostCount = originalRepostCount
              PostStateManager.shared.setReposted(postUri: postUri, repostUri: repostUri)
            }
          }
        }
      }
    } else {
      // リポスト

      // ローカル状態を即座に更新
      let originalViewer = post.viewer
      let originalRepostCount = post.repostCount

      // 仮のURI
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

      // サーバー通信
      Task {
        do {
          let newRepostUri = try await InteractionService.shared.repost(post: post)
          print("リポスト成功: \(newRepostUri)")

          // 正しいURIで更新
          await MainActor.run {
            // ユーザーが連打していないか確認
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
          print("リポスト失敗: \(error)")
          // ロールバック
          await MainActor.run {
            post.viewer = originalViewer
            post.repostCount = originalRepostCount
            PostStateManager.shared.removeReposted(postUri: postUri)
          }
        }
      }
    }

    isReposting = false
  }
}
