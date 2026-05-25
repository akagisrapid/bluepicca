import SwiftData
import SwiftUI

struct TimelineCardView: View {
  let viewModel: TimelineCardViewModel
  @ObservedObject var post: Post
  @State private var isShowingReplySheet = false
  @State private var hashtagSearchItem: HashtagSearchItem? = nil
  @State private var isSensitiveRevealed = false
  @State private var likeScale: CGFloat = 1.0
  @State private var repostScale: CGFloat = 1.0
  @Environment(\.modelContext) private var modelContext
  @Query private var bookmarks: [BookmarkedPost]
  @ObservedObject private var rtFilterManager = RTFilterManager.shared
  @ScaledMetric(relativeTo: .subheadline) private var timelineAvatarSize: CGFloat = 30

  init(viewModel: TimelineCardViewModel) {
    self.viewModel = viewModel
    self._post = ObservedObject(wrappedValue: viewModel.post)
  }

  private var isBookmarked: Bool {
    guard let uri = viewModel.post.uri else { return false }
    return bookmarks.contains { $0.postUri == uri }
  }

  private func triggerLikeAnimation() {
    likeScale = 1.5
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { likeScale = 1.0 }
  }

  private func triggerRepostAnimation() {
    repostScale = 1.5
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { repostScale = 1.0 }
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
      }

      // リプライ情報バナー（スレッドルートへのリンク付き）
      if viewModel.isReply {
        NavigationLink(
          destination: PostDetailView(
            viewModel: PostDetailViewModel(post: viewModel.replyRootPost ?? viewModel.post))
        ) {
          HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left")
              .font(.caption2)
            Text("\(viewModel.replyTargetAuthorName)への返信")
              .font(.caption2)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption2)
          }
          .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, viewModel.isRepost ? 0 : 8)
        .padding(.bottom, 4)
        .overlay {
          // 上のカードとスレッド接続しているときだけバナー部分にも縦線を引く
          if viewModel.connectsToCardAbove {
            HStack(spacing: 0) {
              Color.clear.frame(width: timelineAvatarSize)
              Color.accentColor.opacity(0.35).frame(width: 2)
              Spacer()
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 0) {
        // ヘッダー: アバター + 著者情報 + 時刻
        HStack(alignment: .top, spacing: 10) {
          ProfileImageView(
            viewModel: AsyncImageViewModel(
              url: viewModel.post.author?.avatarUrl,
              imageSize: .timeline,
              alt: viewModel.authorName),
            actor: viewModel.post.author?.did ?? "")

          VStack(alignment: .leading, spacing: 1) {
            Text(viewModel.authorName)
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
              .lineLimit(1)
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
        .padding(.horizontal, 16)
        .padding(.top, (viewModel.isRepost || viewModel.isReply) ? 0 : 10)
        .padding(.bottom, 6)

        // センシティブコンテンツ警告または本文・メディア
        if viewModel.post.isSensitive && !isSensitiveRevealed {
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
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
        } else {
          // 本文テキスト（メイン）
          if !viewModel.text.isEmpty {
            PostTextView(text: viewModel.text) { tag in
              hashtagSearchItem = HashtagSearchItem(query: tag)
            }
            .font(.body)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
          }

          // 添付画像サムネイル
          if let images = viewModel.post.embed?.resolvedImages, !images.isEmpty {
            ImageGridView(images: images)
              .padding(.horizontal, 16)
              .padding(.bottom, 8)
          }

          // 動画バッジ（サムネイルなし）
          if viewModel.videoCount > 0 {
            HStack(spacing: 6) {
              MediaBadge(icon: "play.rectangle", label: "動画")
              Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
          }

          // 引用ポスト（存在する場合のみ）
          if let quoted = viewModel.quotedPost {
            QuotePostCard(quoted: quoted)
              .padding(.horizontal, 16)
              .padding(.bottom, 8)
          }

          // リンクカード（外部リンク埋め込みがある場合のみ）
          if let externalLink = viewModel.externalLink {
            CompactLinkCard(externalLink: externalLink)
              .padding(.horizontal, 16)
              .padding(.bottom, 8)
          }
        }

        // アクションバー: リプライ・リポスト・いいね
        HStack(spacing: 0) {
          // リプライボタン（Threadgateで制限中はグレーアウト＋ロックバッジ）
          Button(action: {
            isShowingReplySheet = true
          }) {
            HStack(spacing: 4) {
              ZStack(alignment: .topTrailing) {
                Image(systemName: viewModel.isReplyDisabled ? "bubble.left.fill" : "bubble.left")
                  .font(.caption)
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
            .frame(minWidth: 44, minHeight: 36)
          }
          .buttonStyle(.plain)
          .disabled(viewModel.isReplyDisabled)
          .accessibilityLabel(
            viewModel.isReplyDisabled ? "返信不可" : "返信 \(viewModel.post.replyCount ?? 0)件")

          Spacer()

          // リポストボタン
          Button(action: {
            Task { await viewModel.toggleRepost() }
            triggerRepostAnimation()
          }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.rectanglepath")
                .font(.caption)
                .scaleEffect(repostScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: repostScale)
              Text("\(viewModel.repostCount)")
                .font(.caption)
            }
            .foregroundColor(viewModel.isReposted ? .green : .secondary)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isReposted)
            .frame(minWidth: 44, minHeight: 36)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            viewModel.isReposted
              ? "リポスト済み \(viewModel.repostCount)件" : "リポスト \(viewModel.repostCount)件")

          Spacer()

          // いいねボタン
          Button(action: {
            Task { await viewModel.toggleLike() }
            triggerLikeAnimation()
          }) {
            HStack(spacing: 4) {
              Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                .font(.caption)
                .scaleEffect(likeScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: likeScale)
              Text("\(viewModel.likeCount)")
                .font(.caption)
            }
            .foregroundColor(viewModel.isLiked ? .yellow : .secondary)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLiked)
            .frame(minWidth: 44, minHeight: 36)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            viewModel.isLiked ? "いいね済み \(viewModel.likeCount)件" : "いいね \(viewModel.likeCount)件")

          Spacer()

          // ブックマークボタン
          Button(action: { toggleBookmark() }) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
              .font(.caption)
              .foregroundColor(isBookmarked ? .blue : .secondary)
              .frame(minWidth: 44, minHeight: 36)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isBookmarked ? "ブックマーク済み" : "ブックマーク")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
      }  // body VStack
      .overlay {
        if viewModel.connectsToCardAbove || viewModel.connectsToCardBelow {
          HStack(spacing: 0) {
            Color.clear.frame(width: 30)
            Color.accentColor.opacity(0.35).frame(width: 2)
            Spacer()
          }
        }
      }
    }  // root VStack
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button {
        Task { await viewModel.toggleLike() }
        triggerLikeAnimation()
      } label: {
        Image(systemName: viewModel.isLiked ? "star.slash.fill" : "star.fill")
      }
      .tint(.yellow)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button {
        Task { await viewModel.toggleRepost() }
        triggerRepostAnimation()
      } label: {
        Image(systemName: "arrow.rectanglepath")
      }
      .tint(.green)
    }
    .sheet(isPresented: $isShowingReplySheet) {
      ReplyPostCardView(post: viewModel.post, isShowReplyCard: $isShowingReplySheet)
    }
    .sheet(item: $hashtagSearchItem) { item in
      SearchView(initialQuery: item.query)
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
            AsyncImage(url: quoted.author?.avatarUrl) { image in
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
      AsyncImage(url: quoted.avatarUrl) { image in
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

// MARK: - 画像グリッド（1〜4枚対応、タイムラインではタップで詳細画面へ遷移）

private struct ImageGridView: View {
  let images: [EmbedImagesViewItem]

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
          ThumbView(url: images[0].thumbUrl)
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case 2:
          HStack(spacing: 2) {
            ThumbView(url: images[0].thumbUrl)
            ThumbView(url: images[1].thumbUrl)
          }
          .frame(width: w, height: h)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        case 3:
          HStack(spacing: 2) {
            ThumbView(url: images[0].thumbUrl)
            VStack(spacing: 2) {
              ThumbView(url: images[1].thumbUrl)
              ThumbView(url: images[2].thumbUrl)
            }
          }
          .frame(width: w, height: h)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        default:
          VStack(spacing: 2) {
            HStack(spacing: 2) {
              ThumbView(url: images[0].thumbUrl)
              ThumbView(url: images[1].thumbUrl)
            }
            HStack(spacing: 2) {
              ThumbView(url: images[2].thumbUrl)
              ThumbView(url: images[3].thumbUrl)
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
