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
    Link(destination: URL(string: externalLink.uri) ?? URL(string: "https://example.com")!) {
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

// MARK: - 画像グリッド（1〜4枚対応）

private struct ImageGridView: View {
  let images: [EmbedImagesViewItem]

  var body: some View {
    let count = min(images.count, 4)
    switch count {
    case 1:
      SingleImageView(image: images[0])
    case 2:
      HStack(spacing: 2) {
        ForEach(0..<2, id: \.self) { i in
          ThumbView(url: images[i].thumbUrl)
        }
      }
      .frame(height: 160)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    case 3:
      HStack(spacing: 2) {
        ThumbView(url: images[0].thumbUrl)
        VStack(spacing: 2) {
          ThumbView(url: images[1].thumbUrl)
          ThumbView(url: images[2].thumbUrl)
        }
      }
      .frame(height: 160)
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
      .frame(height: 200)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct SingleImageView: View {
  let image: EmbedImagesViewItem

  private var aspectRatio: CGFloat {
    guard let ar = image.aspectRatio, ar.width > 0 else { return 16 / 9 }
    let ratio = CGFloat(ar.width) / CGFloat(ar.height)
    return min(max(ratio, 0.5), 3.0)
  }

  var body: some View {
    ThumbView(url: image.thumbUrl)
      .aspectRatio(aspectRatio, contentMode: .fill)
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 300)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct ThumbView: View {
  let url: URL?

  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFill()
      case .failure:
        Color(.systemGray5)
          .overlay(Image(systemName: "photo").foregroundColor(.secondary))
      default:
        Color(.systemGray6)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }
}
