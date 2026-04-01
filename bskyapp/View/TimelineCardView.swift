import SwiftUI
import SwiftData

struct TimelineCardView: View {
  let viewModel: TimelineCardViewModel
  @ObservedObject var post: Post
  @State private var isShowingReplySheet = false
  @State private var hashtagSearchItem: HashtagSearchItem? = nil
  @Environment(\.modelContext) private var modelContext
  @Query private var bookmarks: [BookmarkedPost]

  init(viewModel: TimelineCardViewModel) {
    self.viewModel = viewModel
    self._post = ObservedObject(wrappedValue: viewModel.post)
  }

  private var isBookmarked: Bool {
    guard let uri = viewModel.post.uri else { return false }
    return bookmarks.contains { $0.postUri == uri }
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
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
      }

      // リプライ情報バナー
      if viewModel.isReply {
        HStack(spacing: 4) {
          Image(systemName: "arrowshape.turn.up.left")
            .font(.caption2)
          Text("\(viewModel.replyTargetAuthorName)への返信")
            .font(.caption2)
          Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.top, viewModel.isRepost ? 0 : 8)
        .padding(.bottom, 4)
      }

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
      if let images = viewModel.post.embed?.images, !images.isEmpty {
        ImageGridView(images: images)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
      }

      // 動画バッジ
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

      // アクションバー: リプライ・リポスト・いいね
      HStack(spacing: 0) {
        // リプライボタン
        Button(action: {
          isShowingReplySheet = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "bubble.left")
              .font(.caption)
            Text("\(viewModel.post.replyCount ?? 0)")
              .font(.caption)
          }
          .foregroundColor(.secondary)
          .frame(minWidth: 44, minHeight: 36)
        }
        .buttonStyle(.plain)

        Spacer()

        // リポストボタン
        Button(action: {
          Task { await viewModel.toggleRepost() }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "arrow.rectanglepath")
              .font(.caption)
            Text("\(viewModel.repostCount)")
              .font(.caption)
          }
          .foregroundColor(viewModel.isReposted ? .green : .secondary)
          .frame(minWidth: 44, minHeight: 36)
        }
        .buttonStyle(.plain)

        Spacer()

        // いいねボタン
        Button(action: {
          Task { await viewModel.toggleLike() }
        }) {
          HStack(spacing: 4) {
            Image(systemName: viewModel.isLiked ? "star.fill" : "star")
              .font(.caption)
            Text("\(viewModel.likeCount)")
              .font(.caption)
          }
          .foregroundColor(viewModel.isLiked ? .yellow : .secondary)
          .frame(minWidth: 44, minHeight: 36)
        }
        .buttonStyle(.plain)

        Spacer()

        // ブックマークボタン
        Button(action: { toggleBookmark() }) {
          Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .font(.caption)
            .foregroundColor(isBookmarked ? .blue : .secondary)
            .frame(minWidth: 44, minHeight: 36)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 4)
    }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button {
        Task { await viewModel.toggleLike() }
      } label: {
        Image(systemName: viewModel.isLiked ? "star.slash.fill" : "star.fill")
      }
      .tint(.yellow)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button {
        Task { await viewModel.toggleRepost() }
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

  var body: some View {
    NavigationLink(destination: PostDetailView(viewModel: PostDetailViewModel(post: quotedAsPost))) {
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

// MARK: - 画像グリッド（1〜4枚、タップでフルスクリーン）

private struct ImageGridView: View {
  let images: [EmbedImagesViewItem]
  @State private var viewerIndex: Int? = nil

  var body: some View {
    let count = min(images.count, 4)
    Group {
      switch count {
      case 1:
        SingleThumbView(image: images[0])
          .onTapGesture { viewerIndex = 0 }
      case 2:
        HStack(spacing: 2) {
          ForEach(0..<2, id: \.self) { i in
            ThumbTile(url: images[i].thumbUrl, alt: images[i].alt)
              .onTapGesture { viewerIndex = i }
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      case 3:
        HStack(spacing: 2) {
          ThumbTile(url: images[0].thumbUrl, alt: images[0].alt)
            .onTapGesture { viewerIndex = 0 }
          VStack(spacing: 2) {
            ThumbTile(url: images[1].thumbUrl, alt: images[1].alt)
              .onTapGesture { viewerIndex = 1 }
            ThumbTile(url: images[2].thumbUrl, alt: images[2].alt)
              .onTapGesture { viewerIndex = 2 }
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      default:
        VStack(spacing: 2) {
          HStack(spacing: 2) {
            ThumbTile(url: images[0].thumbUrl, alt: images[0].alt)
              .onTapGesture { viewerIndex = 0 }
            ThumbTile(url: images[1].thumbUrl, alt: images[1].alt)
              .onTapGesture { viewerIndex = 1 }
          }
          HStack(spacing: 2) {
            ThumbTile(url: images[2].thumbUrl, alt: images[2].alt)
              .onTapGesture { viewerIndex = 2 }
            ThumbTile(url: images[3].thumbUrl, alt: images[3].alt)
              .onTapGesture { viewerIndex = 3 }
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .fullScreenCover(item: Binding(
      get: { viewerIndex.map { ImageViewerItem(index: $0) } },
      set: { viewerIndex = $0?.index }
    )) { item in
      FullScreenImageView(images: images, initialIndex: item.index)
    }
  }
}

private struct SingleThumbView: View {
  let image: EmbedImagesViewItem

  private var imageHeight: CGFloat {
    guard let ar = image.aspectRatio, ar.width > 0, ar.height > 0 else { return 220 }
    let availableWidth = UIScreen.main.bounds.width - 32
    let natural = availableWidth * CGFloat(ar.height) / CGFloat(ar.width)
    return min(max(natural, 100), 300)
  }

  var body: some View {
    CachedAsyncImage(url: image.thumbUrl) { img in
      img.resizable().scaledToFill()
    } placeholder: {
      Color(.systemGray6)
    }
    .frame(maxWidth: .infinity)
    .frame(height: imageHeight)
    .clipped()
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityLabel(image.alt.isEmpty ? "画像" : image.alt)
  }
}

private struct ThumbTile: View {
  let url: URL?
  let alt: String

  var body: some View {
    CachedAsyncImage(url: url) { img in
      img.resizable().scaledToFill()
    } placeholder: {
      Color(.systemGray6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .accessibilityLabel(alt.isEmpty ? "画像" : alt)
  }
}

private struct ImageViewerItem: Identifiable {
  let id = UUID()
  let index: Int
}
