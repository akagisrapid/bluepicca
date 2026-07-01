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
  @State private var viewingImageIndex: Int? = nil
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
      let wasLiked = viewModel.isLiked
      Task {
        await viewModel.toggleLike()
        ToastManager.shared.show(
          icon: wasLiked ? "star.slash" : "star.fill",
          text: wasLiked ? "いいねを取り消し" : "いいね"
        )
      }
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
      let wasBookmarked = isBookmarked
      toggleBookmark()
      ToastManager.shared.show(
        icon: wasBookmarked ? "bookmark.slash" : "bookmark.fill",
        text: wasBookmarked ? "ブックマークを削除" : "ブックマーク"
      )
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
    highlightMenuItems
    shareMenuItem
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
        let wasLiked = viewModel.isLiked
        Task {
          await viewModel.toggleLike()
          ToastManager.shared.show(
            icon: wasLiked ? "star.slash" : "star.fill",
            text: wasLiked ? "いいねを取り消し" : "いいね"
          )
        }
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
        let wasBookmarked = isBookmarked
        toggleBookmark()
        ToastManager.shared.show(
          icon: wasBookmarked ? "bookmark.slash" : "bookmark.fill",
          text: wasBookmarked ? "ブックマークを削除" : "ブックマーク"
        )
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
              ImageGridView(images: images) { index in
                viewingImageIndex = index
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
    .confirmationDialog("", isPresented: $showRepostMenu, titleVisibility: .hidden) {
      Button(viewModel.isReposted ? "リポストを取り消す" : "リポスト") {
        let wasReposted = viewModel.isReposted
        Task {
          await viewModel.toggleRepost()
          ToastManager.shared.show(
            icon: "arrow.rectanglepath",
            text: wasReposted ? "リポストを取り消し" : "リポスト"
          )
        }
      }
      Button("引用ポスト") { isShowingQuoteSheet = true }
      Button("キャンセル", role: .cancel) {}
    }
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
    .fullScreenCover(
      item: Binding(
        get: { viewingImageIndex.map { IdentifiableInt(value: $0) } },
        set: { viewingImageIndex = $0?.value }
      )
    ) { item in
      if let images = viewModel.post.embed?.resolvedImages {
        FullScreenImageView(images: images, initialIndex: item.value)
      }
    }
  }
}

// MARK: - 添付メディアバッジ（ピル形状）

private struct MediaBadge: View {
  let icon: String
  let label: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption2)
      Text(label)
        .font(.caption2)
    }
    .foregroundColor(.secondary)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color(.systemGray6))
    .clipShape(Capsule())
  }
}

// MARK: - 引用ポストカード

struct QuotePostCard: View {
  let quoted: EmbeddedRecordViewItem
  @AppStorage("hideImagePreview") private var hideImagePreview: Bool = false

  private var quotedAsPost: Post {
    Post(uri: quoted.uri, cid: nil, author: quoted.author, record: quoted.value)
  }

  private var quotedImages: [EmbedImagesViewItem] {
    quoted.embeds?.compactMap { $0.images }.first ?? []
  }

  var body: some View {
    if quoted.isFeedGenerator {
      FeedGeneratorCard(quoted: quoted)
    } else {
      NavigationLink(
        destination: PostDetailView(viewModel: PostDetailViewModel(post: quotedAsPost))
      ) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            CachedAsyncImage(url: quoted.author?.avatarUrl) { image in
              image.resizable()
            } placeholder: {
              Circle().fill(Color(.systemGray5))
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())

            Text(quoted.author?.displayName ?? quoted.author?.handle ?? "")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
              .lineLimit(1)

            Text("@\(quoted.author?.handle ?? "")")
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          if let text = quoted.value?.text, !text.isEmpty {
            Text(text)
              .font(.caption)
              .foregroundColor(.primary)
              .lineLimit(4)
          }

          if !quotedImages.isEmpty {
            if hideImagePreview {
              MediaBadge(
                icon: "photo",
                label: quotedImages.count == 1 ? "画像" : "画像 \(quotedImages.count)枚")
            } else {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                  ForEach(quotedImages.prefix(4), id: \.thumb) { image in
                    CachedAsyncImage(url: image.thumbUrl) { img in
                      img.resizable().scaledToFill()
                    } placeholder: {
                      Color(.systemGray5).overlay(ProgressView().tint(.secondary))
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                  }
                }
              }
            }
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - フィードジェネレーターカード

private struct FeedGeneratorCard: View {
  let quoted: EmbeddedRecordViewItem

  var body: some View {
    NavigationLink(
      destination: FeedGeneratorTimelineView(
        feedUri: quoted.uri ?? "",
        feedName: quoted.displayName ?? "フィード"
      )
    ) {
      cardContent
    }
    .buttonStyle(.plain)
  }

  private var cardContent: some View {
    HStack(spacing: 10) {
      CachedAsyncImage(url: quoted.avatarUrl) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
          .overlay(Image(systemName: "list.star").font(.caption).foregroundColor(.secondary))
      }
      .frame(width: 36, height: 36)
      .clipShape(RoundedRectangle(cornerRadius: 6))

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Image(systemName: "list.star")
            .font(.caption2)
            .foregroundColor(.secondary)
          Text("フィード")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        Text(quoted.displayName ?? "")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
          .lineLimit(1)
        if let description = quoted.description, !description.isEmpty {
          Text(description)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
        if let creator = quoted.creator {
          Text("by \(creator.displayName ?? creator.handle ?? "")")
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(.systemGray4), lineWidth: 0.5)
    )
  }
}

// MARK: - タイムライン用コンパクトリンクカード

private struct CompactLinkCard: View {
  let externalLink: EmbeddedExternalViewItem

  var body: some View {
    if let destination = URL(string: externalLink.uri) {
      Link(destination: destination) {
        HStack(spacing: 10) {
          Image(systemName: "link")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 16)

          VStack(alignment: .leading, spacing: 1) {
            Text(externalLink.title.isEmpty ? displayHost : externalLink.title)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.primary)
              .lineLimit(1)
            if !externalLink.description.isEmpty {
              Text(externalLink.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
            Text(displayHost)
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
  }

  private var displayHost: String {
    guard let url = URL(string: externalLink.uri), let host = url.host else {
      return externalLink.uri
    }
    return host
  }
}

struct HashtagSearchItem: Identifiable {
  let id = UUID()
  let query: String
}

// MARK: - 画像グリッド（1〜4枚対応、タップでフルスクリーン表示）

private struct ImageGridView: View {
  let images: [EmbedImagesViewItem]
  let onTap: (Int) -> Void

  private func aspectRatioValue(for image: EmbedImagesViewItem) -> CGFloat {
    guard let ar = image.aspectRatio, ar.width > 0 else { return 16.0 / 9.0 }
    return min(max(CGFloat(ar.width) / CGFloat(ar.height), 0.5), 3.0)
  }

  private func gridHeight(count: Int, width: CGFloat) -> CGFloat {
    switch count {
    case 1: return min(width / aspectRatioValue(for: images[0]), 300)
    case 2, 3: return 160
    default: return 200
    }
  }

  var body: some View {
    let count = min(images.count, 4)
    GeometryReader { geo in
      let w = geo.size.width
      let h = gridHeight(count: count, width: w)
      Group {
        switch count {
        case 1:
          TappableThumbView(url: images[0].thumbUrl) { onTap(0) }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case 2:
          HStack(spacing: 2) {
            TappableThumbView(url: images[0].thumbUrl) { onTap(0) }
            TappableThumbView(url: images[1].thumbUrl) { onTap(1) }
          }
          .frame(width: w, height: h)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        case 3:
          HStack(spacing: 2) {
            TappableThumbView(url: images[0].thumbUrl) { onTap(0) }
            VStack(spacing: 2) {
              TappableThumbView(url: images[1].thumbUrl) { onTap(1) }
              TappableThumbView(url: images[2].thumbUrl) { onTap(2) }
            }
          }
          .frame(width: w, height: h)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        default:
          VStack(spacing: 2) {
            HStack(spacing: 2) {
              TappableThumbView(url: images[0].thumbUrl) { onTap(0) }
              TappableThumbView(url: images[1].thumbUrl) { onTap(1) }
            }
            HStack(spacing: 2) {
              TappableThumbView(url: images[2].thumbUrl) { onTap(2) }
              TappableThumbView(url: images[3].thumbUrl) { onTap(3) }
            }
          }
          .frame(width: w, height: h)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .frame(
      maxWidth: .infinity,
      minHeight: gridHeight(count: count, width: UIScreen.main.bounds.width - 32))
  }
}

private struct SingleImageView: View {
  let image: EmbedImagesViewItem
  let onTap: () -> Void
  @State private var containerWidth: CGFloat = UIScreen.main.bounds.width - 32

  private var aspectRatioValue: CGFloat {
    guard let ar = image.aspectRatio, ar.width > 0 else { return 16 / 9 }
    let ratio = CGFloat(ar.width) / CGFloat(ar.height)
    return min(max(ratio, 0.5), 3.0)
  }

  private var imageHeight: CGFloat { min(containerWidth / aspectRatioValue, 300) }

  var body: some View {
    Button(action: onTap) {
      CachedAsyncImage(url: image.thumbUrl) { img in
        img.resizable().scaledToFill()
      } placeholder: {
        Color(.systemGray6).overlay(ProgressView().tint(.secondary))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .frame(height: imageHeight)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .background(
      GeometryReader { geo in
        Color.clear.onAppear { containerWidth = geo.size.width }
      }
    )
  }
}

private struct TappableThumbView: View {
  let url: URL?
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      CachedAsyncImage(url: url) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Color(.systemGray6)
          .overlay(ProgressView().tint(.secondary))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    }
    .buttonStyle(.plain)
  }
}

private struct ThumbView: View {
  let url: URL?

  var body: some View {
    CachedAsyncImage(url: url) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      Color(.systemGray6)
        .overlay(ProgressView().tint(.secondary))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }
}

// MARK: - 背景色ピッカーシート

struct HighlightColorPickerView: View {
  let did: String
  let authorName: String
  @ObservedObject private var highlightManager = UserHighlightManager.shared
  @Environment(\.dismiss) private var dismiss

  private let columns = Array(repeating: GridItem(.flexible()), count: 3)

  var body: some View {
    VStack(spacing: 20) {
      Text("\(authorName) の背景色")
        .font(.headline)
        .padding(.top, 20)

      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(UserHighlightManager.presetColors, id: \.hex) { item in
          let isSelected = highlightManager.highlights[did] == item.hex
          Button {
            highlightManager.set(did: did, hex: item.hex)
            dismiss()
          } label: {
            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: item.hex))
                .frame(height: 44)
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                )
              Text(item.label)
                .font(.caption2)
                .foregroundColor(.primary)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 24)

      if highlightManager.hasHighlight(for: did) {
        Button(role: .destructive) {
          highlightManager.remove(did: did)
          dismiss()
        } label: {
          Text("背景色を削除")
            .font(.subheadline)
        }
      }

      Spacer()
    }
  }
}

// MARK: - IdentifiableInt（fullScreenCover用）

private struct IdentifiableInt: Identifiable {
  let value: Int
  var id: Int { value }
}

// MARK: - Color(hex:) extension（HighlightColorPickerView用）

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8) & 0xFF) / 255
    let b = Double(int & 0xFF) / 255
    self.init(red: r, green: g, blue: b)
  }
}
