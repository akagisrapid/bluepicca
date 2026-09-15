import SwiftData
import SwiftUI

struct TimelineCardView: View {
  let viewModel: TimelineCardViewModel
  @ObservedObject var post: Post
  @State private var isShowingReplySheet = false
  @State private var isShowingQuoteSheet = false
  @State private var showRepostMenu = false
  @State private var hashtagSearchItem: HashtagSearchItem? = nil
  @State private var isSensitiveRevealed = false
  @State private var showHighlightPicker = false
  @State private var isShowingPostDetailFromImage = false
  @State private var showMuteUserConfirm = false
  @State private var showMuteWordPicker = false
  @State private var showReportReasonPicker = false
  @State private var mutedOverride: Bool? = nil
  @AppStorage("swipeLeadingAction") private var swipeLeadingActionRaw: String = SwipeAction.like
    .rawValue
  @AppStorage("swipeTrailingAction") private var swipeTrailingActionRaw: String = SwipeAction.repost
    .rawValue
  @AppStorage("hideImagePreview") private var hideImagePreview: Bool = false
  @AppStorage("hideAvatars") private var hideAvatars: Bool = false
  @Environment(\.modelContext) private var modelContext
  @Query private var bookmarks: [BookmarkedPost]
  @ObservedObject private var rtFilterManager = RTFilterManager.shared
  @ObservedObject private var highlightManager = UserHighlightManager.shared
  @ObservedObject private var labelManager = ContentLabelManager.shared
  @ScaledMetric(relativeTo: .subheadline) private var timelineAvatarSize: CGFloat = 30

  init(viewModel: TimelineCardViewModel) {
    self.viewModel = viewModel
    self._post = ObservedObject(wrappedValue: viewModel.post)
  }

  private var isBookmarked: Bool {
    guard let uri = viewModel.post.uri else { return false }
    return bookmarks.contains { $0.postUri == uri }
  }

  private var shareUrl: URL? {
    guard let uri = viewModel.post.uri,
      let handle = viewModel.post.author?.handle
    else { return nil }
    let rkey = String(uri.split(separator: "/").last ?? "")
    guard !rkey.isEmpty else { return nil }
    return URL(string: "https://bsky.app/profile/\(handle)/post/\(rkey)")
  }

  private var authorHighlightColor: Color? {
    guard let did = viewModel.post.author?.did else { return nil }
    return highlightManager.color(for: did)
  }

  private var isAuthorMuted: Bool {
    mutedOverride ?? (viewModel.post.author?.viewer?.muted ?? false)
  }

  private func toggleUserMute() {
    guard let did = viewModel.post.author?.did else { return }
    let wasMuted = isAuthorMuted
    mutedOverride = !wasMuted
    if wasMuted {
      MutedUsersManager.shared.remove(did: did)
    } else {
      MutedUsersManager.shared.add(did: did)
    }
    Task {
      do {
        if wasMuted {
          try await MuteBlockApi.unmuteActor(did: did)
        } else {
          try await MuteBlockApi.muteActor(did: did)
        }
        ToastManager.shared.show(
          icon: wasMuted ? "speaker.wave.2.fill" : "speaker.slash.fill",
          text: wasMuted ? "ミュートを解除" : "ユーザーをミュート"
        )
      } catch {
        dlog("toggleUserMute error: \(error)")
        mutedOverride = wasMuted
        if wasMuted {
          MutedUsersManager.shared.add(did: did)
        } else {
          MutedUsersManager.shared.remove(did: did)
        }
        ToastManager.shared.show(
          icon: "exclamationmark.triangle",
          text: "\(wasMuted ? "ミュート解除" : "ミュート")失敗: \(error.localizedDescription)",
          durationMilliseconds: 4000
        )
      }
    }
  }

  private func toggleBookmark() {
    guard let uri = viewModel.post.uri else { return }
    if let existing = bookmarks.first(where: { $0.postUri == uri }) {
      modelContext.delete(existing)
    } else {
      let bookmark = BookmarkedPost(
        postUri: uri,
        postCid: viewModel.post.cid ?? "",
        authorDisplayName: viewModel.authorName,
        authorHandle: viewModel.post.author?.handle ?? "",
        authorAvatarUrl: viewModel.post.author?.avatarUrl?.absoluteString,
        text: viewModel.text
      )
      modelContext.insert(bookmark)
    }
  }

  // MARK: - トースト付きアクション（コンテキストメニュー・スワイプ・リポストダイアログで共有）

  private func likeWithToast() {
    let wasLiked = viewModel.isLiked
    Task {
      await viewModel.toggleLike()
      ToastManager.shared.show(
        icon: wasLiked ? "star.slash" : "star.fill",
        text: wasLiked ? "いいねを取り消し" : "いいね"
      )
    }
  }

  private func repostWithToast() {
    let wasReposted = viewModel.isReposted
    Task {
      await viewModel.toggleRepost()
      ToastManager.shared.show(
        icon: "arrow.rectanglepath",
        text: wasReposted ? "リポストを取り消し" : "リポスト"
      )
    }
  }

  private func bookmarkWithToast() {
    let wasBookmarked = isBookmarked
    toggleBookmark()
    ToastManager.shared.show(
      icon: wasBookmarked ? "bookmark.slash" : "bookmark.fill",
      text: wasBookmarked ? "ブックマークを削除" : "ブックマーク"
    )
  }

  private func reportPost(reasonType: String) {
    guard let uri = viewModel.post.uri, let cid = viewModel.post.cid else { return }
    Task {
      do {
        try await ModerationReportApi.createReport(uri: uri, cid: cid, reasonType: reasonType)
        ToastManager.shared.show(icon: "flag.fill", text: "報告しました")
      } catch {
        dlog("reportPost error: \(error)")
        ToastManager.shared.show(
          icon: "exclamationmark.triangle",
          text: "報告に失敗しました: \(error.localizedDescription)",
          durationMilliseconds: 4000
        )
      }
    }
  }

  @ViewBuilder
  private var contextMenuItems: some View {
    Button {
      isShowingReplySheet = true
    } label: {
      SwiftUI.Label("返信", systemImage: "bubble.left")
    }
    Button {
      isShowingQuoteSheet = true
    } label: {
      SwiftUI.Label("引用ポスト", systemImage: "quote.bubble")
    }
    Divider()
    Button {
      likeWithToast()
    } label: {
      SwiftUI.Label(
        viewModel.isLiked ? "いいねを取り消す" : "いいね",
        systemImage: viewModel.isLiked ? "star.slash" : "star")
    }
    Button {
      showRepostMenu = true
    } label: {
      SwiftUI.Label(
        viewModel.isReposted ? "リポストを取り消す" : "リポスト",
        systemImage: "arrow.rectanglepath")
    }
    Button {
      bookmarkWithToast()
    } label: {
      SwiftUI.Label(
        isBookmarked ? "ブックマークを削除" : "ブックマーク",
        systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
    }
    Divider()
    Button {
      UIPasteboard.general.string = viewModel.text
    } label: {
      SwiftUI.Label("テキストをコピー", systemImage: "doc.on.doc")
    }
    if let url = shareUrl {
      Button {
        UIPasteboard.general.string = url.absoluteString
      } label: {
        SwiftUI.Label("URLをコピー", systemImage: "link")
      }
    }
    rtFilterMenuItems
    muteMenuItems
    reportMenuItems
    highlightMenuItems
    shareMenuItem
  }

  @ViewBuilder
  private var muteMenuItems: some View {
    if viewModel.post.author?.did != nil {
      Divider()
      Button(role: isAuthorMuted ? .none : .destructive) {
        showMuteUserConfirm = true
      } label: {
        SwiftUI.Label(
          isAuthorMuted ? "ミュートを解除" : "このユーザーをミュート",
          systemImage: isAuthorMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
      }
      Button {
        showMuteWordPicker = true
      } label: {
        SwiftUI.Label("ミュートワードを追加", systemImage: "text.badge.xmark")
      }
    }
  }

  @ViewBuilder
  private var reportMenuItems: some View {
    Divider()
    Button(role: .destructive) {
      showReportReasonPicker = true
    } label: {
      SwiftUI.Label("投稿を報告", systemImage: "flag")
    }
  }

  @ViewBuilder
  private var rtFilterMenuItems: some View {
    if viewModel.isRepost, let did = viewModel.repostAuthorDid {
      Divider()
      Button {
        if rtFilterManager.isFiltered(did) {
          rtFilterManager.remove(did: did)
        } else {
          rtFilterManager.add(
            did: did,
            displayName: viewModel.repostAuthorName,
            handle: viewModel.repostAuthorHandle,
            avatarUrl: viewModel.repostAuthorAvatarUrl
          )
        }
      } label: {
        SwiftUI.Label(
          rtFilterManager.isFiltered(did) ? "このユーザーのRTを再表示" : "このユーザーのRTを非表示",
          systemImage: rtFilterManager.isFiltered(did) ? "eye" : "eye.slash")
      }
    }
  }

  @ViewBuilder
  private var highlightMenuItems: some View {
    if let did = viewModel.post.author?.did {
      Divider()
      Button {
        showHighlightPicker = true
      } label: {
        SwiftUI.Label("背景色を設定", systemImage: "paintpalette")
      }
      if highlightManager.hasHighlight(for: did) {
        Button(role: .destructive) {
          highlightManager.remove(did: did)
        } label: {
          SwiftUI.Label("背景色を削除", systemImage: "paintbrush.pointed")
        }
      }
    }
  }

  @ViewBuilder
  private var shareMenuItem: some View {
    if let url = shareUrl {
      Divider()
      ShareLink(item: url) {
        SwiftUI.Label("シェア", systemImage: "square.and.arrow.up")
      }
    }
  }

  @ViewBuilder
  private func swipeButton(for action: SwipeAction) -> some View {
    switch action {
    case .like:
      Button {
        likeWithToast()
      } label: {
        Image(systemName: viewModel.isLiked ? "star.slash.fill" : "star.fill")
      }
      .tint(.yellow)
    case .repost:
      Button {
        showRepostMenu = true
      } label: {
        Image(systemName: "arrow.rectanglepath")
      }
      .tint(.green)
    case .reply:
      Button {
        isShowingReplySheet = true
      } label: {
        Image(systemName: "bubble.left.fill")
      }
      .tint(.blue)
    case .bookmark:
      Button {
        bookmarkWithToast()
      } label: {
        Image(systemName: isBookmarked ? "bookmark.slash.fill" : "bookmark.fill")
      }
      .tint(.blue)
    case .quote:
      Button {
        isShowingQuoteSheet = true
      } label: {
        Image(systemName: "quote.bubble.fill")
      }
      .tint(.purple)
    case .none:
      EmptyView()
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // リポスト情報バナー
      if viewModel.isRepost {
        HStack(spacing: 4) {
          Image(systemName: "repeat")
            .font(.caption2)
          Text("\(viewModel.repostAuthorName)がリポスト")
            .font(.caption2)
          Spacer()
          if let did = viewModel.repostAuthorDid {
            let isFiltered = rtFilterManager.isFiltered(did)
            Button {
              if isFiltered {
                rtFilterManager.remove(did: did)
              } else {
                rtFilterManager.add(
                  did: did,
                  displayName: viewModel.repostAuthorName,
                  handle: viewModel.repostAuthorHandle,
                  avatarUrl: viewModel.repostAuthorAvatarUrl
                )
              }
            } label: {
              Image(systemName: isFiltered ? "eye.slash.fill" : "eye.slash")
                .font(.caption2)
                .foregroundColor(isFiltered ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
          }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
      }

      VStack(alignment: .leading, spacing: 0) {
        // ヘッダー: アバター + 著者情報 + 時刻
        HStack(alignment: .top, spacing: 10) {
          if !hideAvatars {
            ProfileImageView(
              viewModel: AsyncImageViewModel(
                url: viewModel.post.author?.avatarUrl,
                imageSize: .timeline,
                alt: viewModel.authorName),
              actor: viewModel.post.author?.did ?? "")
          }

          VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
              Text(viewModel.authorName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
              if viewModel.isReply {
                Image(systemName: "arrowshape.turn.up.left.fill")
                  .font(.system(size: 9))
                  .foregroundColor(.secondary)
                Text(viewModel.replyTargetAuthorName)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
            Text(viewModel.authorHandle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Spacer()

          Text(viewModel.postedTimeRelative)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.top, viewModel.isRepost ? 0 : 8)
        .padding(.bottom, 5)

        // リプライ先プレビュー
        if viewModel.isReply,
          let parentPost = viewModel.replyParentPost,
          !viewModel.connectsToCardAbove
        {
          NavigationLink(
            destination: PostDetailView(viewModel: PostDetailViewModel(post: parentPost))
          ) {
            HStack(spacing: 6) {
              Image(systemName: "bubble.left.fill")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
              Text(viewModel.replyTargetText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
              Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .padding(.bottom, 6)
        }

        // センシティブコンテンツ警告または本文・メディア
        if labelManager.policy(for: viewModel.post) == .blur && !isSensitiveRevealed {
          Button(action: { isSensitiveRevealed = true }) {
            HStack(spacing: 8) {
              Image(systemName: "eye.slash")
                .font(.caption)
              Text("センシティブなコンテンツ")
                .font(.caption)
                .fontWeight(.medium)
              Spacer()
              Text("タップして表示")
                .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .padding(.bottom, 6)
        } else {
          // 本文テキスト（メイン）
          if !viewModel.text.isEmpty {
            PostTextView(text: viewModel.text) { tag in
              hashtagSearchItem = HashtagSearchItem(query: tag)
            }
            .font(.body)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 6)
          }

          // 添付画像サムネイル
          if let images = viewModel.post.embed?.resolvedImages, !images.isEmpty {
            if hideImagePreview {
              HStack(spacing: 6) {
                MediaBadge(
                  icon: "photo", label: images.count == 1 ? "画像" : "画像 \(images.count)枚")
                Spacer()
              }
              .padding(.bottom, 6)
            } else {
              PostImageGrid(images: images, quality: .thumbnail) { _ in
                isShowingPostDetailFromImage = true
              }
              .padding(.bottom, 6)
            }
          }

          // 動画バッジ
          if viewModel.videoCount > 0 {
            HStack(spacing: 6) {
              MediaBadge(icon: "play.rectangle", label: "動画")
              Spacer()
            }
            .padding(.bottom, 6)
          }

          // 引用ポスト（存在する場合のみ）
          if let quoted = viewModel.quotedPost {
            QuotePostCard(quoted: quoted)
              .padding(.bottom, 6)
          }

          // リンクカード（外部リンク埋め込みがある場合のみ）
          if let externalLink = viewModel.externalLink {
            CompactLinkCard(externalLink: externalLink)
              .padding(.bottom, 6)
          }
        }

        // アクションバー: 件数表示のみ（操作は長押しメニュー・スワイプで行う）
        HStack(spacing: 0) {
          HStack(spacing: 4) {
            Image(systemName: viewModel.isReplyDisabled ? "bubble.left.fill" : "bubble.left")
              .font(.caption)
              .overlay(alignment: .topTrailing) {
                if viewModel.isReplyDisabled {
                  Image(systemName: "lock.fill")
                    .font(.system(size: 7))
                    .offset(x: 5, y: -5)
                }
              }
            Text("\(viewModel.post.replyCount ?? 0)")
              .font(.caption)
          }
          .foregroundColor(viewModel.isReplyDisabled ? .secondary.opacity(0.4) : .secondary)
          .frame(minWidth: 44, minHeight: 28)

          Spacer()

          HStack(spacing: 4) {
            Image(systemName: "arrow.rectanglepath")
              .font(.caption)
            Text("\(viewModel.repostCount)")
              .font(.caption)
          }
          .foregroundColor(viewModel.isReposted ? .green : .secondary)

          Spacer()

          HStack(spacing: 4) {
            Image(systemName: viewModel.isLiked ? "star.fill" : "star")
              .font(.caption)
            Text("\(viewModel.likeCount)")
              .font(.caption)
          }
          .foregroundColor(viewModel.isLiked ? .yellow : .secondary)

          Spacer()

          Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .font(.caption)
            .foregroundColor(isBookmarked ? .blue : .secondary)
            .frame(minWidth: 44, minHeight: 28)
        }
        .padding(.horizontal, -4)
        .padding(.bottom, 4)
      }  // body VStack
      .padding(.horizontal, 12)
      .overlay {
        if !hideAvatars && (viewModel.connectsToCardAbove || viewModel.connectsToCardBelow) {
          HStack(spacing: 0) {
            Color.clear.frame(width: 12 + timelineAvatarSize / 2 - 1)
            Color.accentColor.opacity(0.35).frame(width: 2)
            Spacer()
          }
        }
      }
    }  // root VStack
    .background(authorHighlightColor?.opacity(0.12))
    .repostConfirmationDialog(
      isPresented: $showRepostMenu,
      isReposted: viewModel.isReposted,
      onRepost: { repostWithToast() },
      onQuote: { isShowingQuoteSheet = true }
    )
    .reportConfirmationDialog(
      isPresented: $showReportReasonPicker,
      onSelectReason: { reasonType in reportPost(reasonType: reasonType) }
    )
    .contextMenu { contextMenuItems }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      swipeButton(for: SwipeAction(rawValue: swipeLeadingActionRaw) ?? .like)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      swipeButton(for: SwipeAction(rawValue: swipeTrailingActionRaw) ?? .repost)
    }
    .sheet(isPresented: $isShowingReplySheet) {
      ReplyPostCardView(post: viewModel.post, isShowReplyCard: $isShowingReplySheet)
    }
    .sheet(isPresented: $isShowingQuoteSheet) {
      QuotePostCardView(post: viewModel.post, isShowQuoteCard: $isShowingQuoteSheet)
    }
    .sheet(item: $hashtagSearchItem) { item in
      SearchView(initialQuery: item.query)
    }
    .sheet(isPresented: $showHighlightPicker) {
      if let did = viewModel.post.author?.did {
        HighlightColorPickerView(
          did: did,
          authorName: viewModel.authorName
        )
        .presentationDetents([.height(280)])
      }
    }
    .navigationDestination(isPresented: $isShowingPostDetailFromImage) {
      PostDetailView(viewModel: PostDetailViewModel(post: post))
    }
  }
}

private struct MuteControlsModifier: ViewModifier {
  @Binding var showMuteWordPicker: Bool
  @Binding var showMuteUserConfirm: Bool
  let text: String
  let authorName: String
  let isAuthorMuted: Bool
  let onToggleMute: () -> Void

  private var alertTitle: String {
    isAuthorMuted ? "ミュートを解除しますか？" : "\(authorName) をミュートしますか？"
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $showMuteWordPicker) {
        MuteWordQuickAddView(text: text)
          .presentationDetents([.medium])
      }
      .alert(alertTitle, isPresented: $showMuteUserConfirm) {
        Button(isAuthorMuted ? "解除" : "ミュート", role: isAuthorMuted ? .none : .destructive) {
          onToggleMute()
        }
        Button("キャンセル", role: .cancel) {}
      }
  }
}

struct HashtagSearchItem: Identifiable {
  let id = UUID()
  let query: String
}
