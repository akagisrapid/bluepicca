import SwiftUI

struct PostDetailView: View {
  @StateObject var viewModel: PostDetailViewModel
  @State private var isShowingReplySheet = false
  @State private var isShowingQuoteSheet = false
  @State private var showRepostMenu = false
  @State private var hashtagSearchItem: HashtagSearchItem? = nil
  @State private var isSensitiveRevealed = false
  @State private var showDeleteConfirm = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {

        // MARK: 親チェーン（スレッドの文脈）
        if !viewModel.parentChain.isEmpty {
          ForEach(viewModel.parentChain) { parentPost in
            ThreadAncestorRow(post: parentPost)
          }
        }

        // MARK: フォーカス投稿
        focusedPost

        Divider()
          .padding(.horizontal, 16)
          .padding(.top, 4)

        // MARK: リプライ一覧
        repliesSection
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.fetchThread()
    }
    .toolbar {
      if viewModel.isOwnPost {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(role: .destructive) {
            showDeleteConfirm = true
          } label: {
            SwiftUI.Label("削除", systemImage: "trash")
              .labelStyle(.iconOnly)
              .foregroundColor(.red)
          }
          .disabled(viewModel.isDeleting)
        }
      }
    }
    .alert("ポストを削除しますか？", isPresented: $showDeleteConfirm) {
      Button("削除", role: .destructive) {
        Task {
          await viewModel.deletePost()
          if viewModel.isDeleted { dismiss() }
        }
      }
      Button("キャンセル", role: .cancel) {}
    } message: {
      Text("この操作は取り消せません。")
    }
    .sheet(isPresented: $isShowingReplySheet) {
      ReplyPostCardView(post: viewModel.post, isShowReplyCard: $isShowingReplySheet)
    }
    .onChange(of: isShowingReplySheet) { _, isShowing in
      if !isShowing {
        Task { await viewModel.refreshAfterReply() }
      }
    }
    .sheet(isPresented: $isShowingQuoteSheet) {
      QuotePostCardView(post: viewModel.post, isShowQuoteCard: $isShowingQuoteSheet)
    }
    .sheet(item: $hashtagSearchItem) { item in
      SearchView(initialQuery: item.query)
    }
  }

  // MARK: - フォーカス投稿

  @ViewBuilder
  private var focusedPost: some View {
    VStack(alignment: .leading, spacing: 0) {

      // リポスト情報
      if viewModel.isRepost {
        HStack(spacing: 4) {
          Image(systemName: "repeat").font(.caption2)
          Text("\(viewModel.repostAuthorName)がリポスト").font(.caption2)
          Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.top, 8)
        .padding(.bottom, 4)
      }

      // 著者ヘッダー
      HStack(alignment: .center, spacing: 10) {
        ProfileImageView(
          viewModel: AsyncImageViewModel(
            url: viewModel.avatarUrl,
            imageSize: .avatar,
            alt: viewModel.displayName
          ),
          actor: viewModel.post.author?.did ?? ""
        )
        VStack(alignment: .leading, spacing: 2) {
          Text(viewModel.displayName)
            .font(.headline)
            .foregroundColor(.primary)
          Text("@\(viewModel.post.author?.handle ?? "")")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .padding(.top, 12)
      .padding(.bottom, 10)

      // センシティブコンテンツ警告またはコンテンツ本体
      if viewModel.post.isSensitive && !isSensitiveRevealed {
        Button(action: { isSensitiveRevealed = true }) {
          HStack(spacing: 10) {
            Image(systemName: "eye.slash")
              .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
              Text("センシティブなコンテンツ")
                .font(.subheadline)
                .fontWeight(.medium)
              Text("タップして表示")
                .font(.caption)
            }
            Spacer()
          }
          .foregroundColor(.secondary)
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
      } else {
        // 本文
        if !viewModel.text.isEmpty {
          PostTextView(text: viewModel.text) { tag in
            hashtagSearchItem = HashtagSearchItem(query: tag)
          }
          .font(.title3)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 12)
        }

        // 引用ポスト
        if let quoted = viewModel.quotedPost {
          QuotePostCard(quoted: quoted)
            .padding(.bottom, 12)
        }

        // 画像
        if !viewModel.embeddedImages.isEmpty {
          PostDetailImageGrid(images: viewModel.embeddedImages)
            .padding(.bottom, 12)
        }

        // 動画
        if let video = viewModel.embeddedVideo {
          VideoPlayerView(video: video)
            .padding(.bottom, 12)
        }

        // リンクカード
        ForEach(viewModel.linkCards, id: \.uri) { externalLink in
          LinkCardView(externalLink: externalLink)
            .padding(.bottom, 8)
        }
      }

      // 投稿日時
      Text(viewModel.indexedAt)
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.vertical, 8)

      Divider()

      // アクションバー
      HStack(spacing: 0) {
        Button(action: { isShowingReplySheet = true }) {
          HStack(spacing: 6) {
            Image(systemName: viewModel.isReplyDisabled ? "bubble.left.fill" : "bubble.left")
              .overlay(alignment: .topTrailing) {
                if viewModel.isReplyDisabled {
                  Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .offset(x: 6, y: -5)
                }
              }
            Text("リプライ")
          }
          .font(.subheadline)
          .foregroundColor(viewModel.isReplyDisabled ? .secondary.opacity(0.4) : .secondary)
          .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isReplyDisabled)

        Spacer()

        Button(action: { Task { await viewModel.toggleLike() } }) {
          HStack(spacing: 6) {
            Image(systemName: viewModel.isLiked ? "star.fill" : "star")
            Text("\(viewModel.likeCount)")
          }
          .font(.subheadline)
          .foregroundColor(viewModel.isLiked ? .yellow : .secondary)
          .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLiking)
        .opacity(viewModel.isLiking ? 0.5 : 1.0)

        Spacer()

        Button(action: { showRepostMenu = true }) {
          HStack(spacing: 6) {
            Image(systemName: "arrow.rectanglepath")
            Text("\(viewModel.repostCount)")
          }
          .font(.subheadline)
          .foregroundColor(viewModel.isReposted ? .green : .secondary)
          .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isReposting)
        .opacity(viewModel.isReposting ? 0.5 : 1.0)
        .repostConfirmationDialog(
          isPresented: $showRepostMenu,
          isReposted: viewModel.isReposted,
          onRepost: { Task { await viewModel.toggleRepost() } },
          onQuote: { isShowingQuoteSheet = true }
        )

        Spacer()
      }
      .padding(.bottom, 4)
    }
    .padding(.horizontal, 16)
  }

  // MARK: - リプライ一覧

  @ViewBuilder
  private var repliesSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      if viewModel.isRoot {
        // 直接リプライを時系列順（フラット）
        ForEach(viewModel.allThreadPosts) { post in
          Divider().padding(.horizontal, 16)
          NavigationLink(
            destination: PostDetailView(viewModel: PostDetailViewModel(post: post, isRoot: false))
          ) {
            MainChainRow(post: post, isLast: true)
          }
          .buttonStyle(.plain)
        }
      } else {
        // メインスレッドチェーン（コネクター付き）
        ForEach(Array(viewModel.mainChain.enumerated()), id: \.element.id) { index, chainPost in
          Divider().padding(.horizontal, 16)
          NavigationLink(
            destination: PostDetailView(
              viewModel: PostDetailViewModel(post: chainPost, isRoot: false))
          ) {
            MainChainRow(
              post: chainPost,
              isLast: index == viewModel.mainChain.count - 1
            )
          }
          .buttonStyle(.plain)
        }
        // 分岐返信
        if !viewModel.branchReplies.isEmpty {
          HStack {
            Text("他の返信 \(viewModel.branchReplies.count)件")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.secondary)
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 8)
          ForEach(viewModel.branchReplies) { reply in
            Divider().padding(.horizontal, 16)
            NavigationLink(
              destination: PostDetailView(
                viewModel: PostDetailViewModel(post: reply.post, isRoot: false))
            ) {
              MainChainRow(post: reply.post, isLast: true)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(.bottom, viewModel.replies.isEmpty ? 0 : 40)
    .frame(minHeight: viewModel.replies.isEmpty || viewModel.isLoadingThread ? 120 : nil)
    .overlay {
      if viewModel.isLoadingThread {
        ProgressView()
      } else if viewModel.replies.isEmpty {
        ContentUnavailableView("リプライはありません", systemImage: "bubble.left")
      }
    }
  }
}

// MARK: - スレッドチェーン返信行（下方向コネクター付き）

private struct MainChainRow: View {
  let post: Post
  let isLast: Bool
  @ScaledMetric(relativeTo: .subheadline) private var avatarColumnWidth: CGFloat = 36

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(spacing: 0) {
        ProfileImageView(
          viewModel: AsyncImageViewModel(
            url: post.author?.avatarUrl,
            imageSize: .timeline,
            alt: post.author?.displayName ?? post.author?.handle ?? ""
          ),
          actor: post.author?.did ?? ""
        )
        if !isLast {
          Rectangle()
            .fill(Color(.systemGray4))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .padding(.top, 4)
        }
      }
      .frame(width: avatarColumnWidth)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 4) {
          Text(post.author?.displayName ?? post.author?.handle ?? "")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .lineLimit(1)
          Text("@\(post.author?.handle ?? "")")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
          Spacer()
          if let indexedAt = post.indexedAt,
            let date = indexedAt.parseToDateRemovingMilliseconds
          {
            Text(date, style: .relative)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        if let text = post.record?.text, !text.isEmpty {
          Text(text)
            .font(.body)
            .foregroundColor(.primary)
            .lineLimit(8)
        }

        if let images = post.embed?.resolvedImages, !images.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
              ForEach(Array(images.prefix(4).enumerated()), id: \.element.thumb) { _, image in
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

        HStack(spacing: 16) {
          if let replyCount = post.replyCount, replyCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "bubble.left").font(.caption)
              Text("\(replyCount)").font(.caption)
            }
            .foregroundColor(.secondary)
          }
          if let likeCount = post.likeCount, likeCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "star").font(.caption)
              Text("\(likeCount)").font(.caption)
            }
            .foregroundColor(.secondary)
          }
        }
        .padding(.top, 2)
      }
      .padding(.bottom, 12)
    }
    .padding(.horizontal, 16)
    .padding(.top, 10)
  }
}

// MARK: - 親投稿行（スレッドコネクター付き）

private struct ThreadAncestorRow: View {
  let post: Post
  @ScaledMetric(relativeTo: .subheadline) private var avatarColumnWidth: CGFloat = 36

  var body: some View {
    NavigationLink(
      destination: PostDetailView(viewModel: PostDetailViewModel(post: post, isRoot: false))
    ) {
      HStack(alignment: .top, spacing: 10) {
        // アバター + スレッドライン
        VStack(spacing: 0) {
          ProfileImageView(
            viewModel: AsyncImageViewModel(
              url: post.author?.avatarUrl,
              imageSize: .timeline,
              alt: post.author?.displayName ?? post.author?.handle ?? ""
            ),
            actor: post.author?.did ?? ""
          )
          Rectangle()
            .fill(Color(.systemGray4))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .padding(.top, 4)
        }
        .frame(width: avatarColumnWidth)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 4) {
            Text(post.author?.displayName ?? post.author?.handle ?? "")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
              .lineLimit(1)
            Text("@\(post.author?.handle ?? "")")
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
            Spacer()
          }
          if let text = post.record?.text, !text.isEmpty {
            Text(text)
              .font(.body)
              .foregroundColor(.secondary)
              .lineLimit(4)
          }
        }
        .padding(.bottom, 12)
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - PostDetail用画像グリッド（高画質表示 + フルスクリーンビュアー）

private struct PostDetailImageGrid: View {
  let images: [EmbedImagesViewItem]
  @State private var viewingIndex: Int? = nil

  var body: some View {
    let count = min(images.count, 4)
    GeometryReader { geo in
      let w = geo.size.width
      Group {
        switch count {
        case 1:
          CachedAsyncImage(url: images[0].fullsizeUrl) { img in
            img.resizable().scaledToFill()
          } placeholder: {
            Color(.systemGray5).overlay(ProgressView())
          }
          .frame(width: w, height: singleImageHeight(for: images[0], width: w))
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .onTapGesture { viewingIndex = 0 }
        case 2:
          HStack(spacing: 3) {
            detailThumb(index: 0)
            detailThumb(index: 1)
          }
          .frame(width: w, height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        case 3:
          HStack(spacing: 3) {
            detailThumb(index: 0)
            VStack(spacing: 3) {
              detailThumb(index: 1)
              detailThumb(index: 2)
            }
          }
          .frame(width: w, height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        default:
          VStack(spacing: 3) {
            HStack(spacing: 3) {
              detailThumb(index: 0)
              detailThumb(index: 1)
            }
            HStack(spacing: 3) {
              detailThumb(index: 2)
              detailThumb(index: 3)
            }
          }
          .frame(width: w, height: 280)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: fallbackGridHeight(count: count))
    .fullScreenCover(
      isPresented: Binding(
        get: { viewingIndex != nil },
        set: { if !$0 { viewingIndex = nil } }
      )
    ) {
      FullScreenImageView(images: images, initialIndex: viewingIndex ?? 0)
    }
  }

  @ViewBuilder
  private func detailThumb(index: Int) -> some View {
    Button {
      viewingIndex = index
    } label: {
      CachedAsyncImage(url: images[index].fullsizeUrl) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Color(.systemGray5)
          .overlay(ProgressView())
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    }
    .buttonStyle(.plain)
  }

  private func singleImageHeight(for image: EmbedImagesViewItem, width: CGFloat) -> CGFloat {
    let ratio: CGFloat
    if let ar = image.aspectRatio, ar.width > 0 {
      ratio = min(max(CGFloat(ar.width) / CGFloat(ar.height), 0.5), 3.0)
    } else {
      ratio = 16 / 9
    }
    return min(width / ratio, 400)
  }

  /// GeometryReader が計測される前の初期 minHeight（レイアウトジャンプ防止）
  private func fallbackGridHeight(count: Int) -> CGFloat {
    switch count {
    case 1: return singleImageHeight(for: images[0], width: UIScreen.main.bounds.width - 32)
    case 2, 3: return 220
    default: return 280
    }
  }
}
