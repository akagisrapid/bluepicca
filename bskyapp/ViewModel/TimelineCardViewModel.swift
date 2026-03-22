import Foundation

struct TimelineCardViewModel {
  let post: Post
  let reason: Reason?
  let reply: Reply?

  init(post: Post, reason: Reason? = nil, reply: Reply? = nil) {
    self.post = post
    self.reason = reason
    self.reply = reply

    // 永続化された状態を復元
    PostInteractionHelper.restorePersistedStates(for: post)
  }
  var authorName: String {
    post.author?.displayName ?? post.author?.handle ?? ""
  }

  var authorHandle: String {
    let handle = post.author?.handle ?? ""
    return handle.isEmpty ? "" : "@\(handle)"
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
    if text.count > 50 {
      return String(text.prefix(50)) + "..."
    }
    return text
  }

  // MARK: - 添付情報

  var imageCount: Int {
    return post.embed?.images?.count ?? 0
  }

  var externalUrl: String? {
    return post.embed?.external?.uri
  }

  var externalLink: EmbeddedExternalViewItem? {
    return post.embed?.external
  }

  var videoCount: Int {
    return post.embed?.video != nil ? 1 : 0
  }

  // MARK: - いいね機能

  var isLiked: Bool {
    return post.viewer?.like != nil
  }

  @MainActor
  func toggleLike() async {
    await PostInteractionHelper.toggleLike(post: post)
  }

  // MARK: - リポスト機能

  var isReposted: Bool {
    return post.viewer?.repost != nil
  }

  var repostCount: Int {
    return post.repostCount ?? 0
  }

  @MainActor
  func toggleRepost() async {
    await PostInteractionHelper.toggleRepost(post: post)
  }
}
