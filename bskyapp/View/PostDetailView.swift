import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    @State private var isShowingReplySheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // リプライ元プレビュー
                if viewModel.isReply {
                    NavigationLink(
                        destination: PostDetailView(
                            viewModel: PostDetailViewModel(post: viewModel.parentPost!)
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption2)
                                Text("返信先")
                                    .font(.caption2)
                                Spacer()
                            }
                            .foregroundColor(.secondary)

                            HStack(alignment: .top, spacing: 10) {
                                ProfileImageView(
                                    viewModel: AsyncImageViewModel(
                                        url: viewModel.parentAvatarUrl,
                                        imageSize: .timeline,
                                        alt: viewModel.parentAuthorName
                                    ),
                                    actor: viewModel.parentAuthorDid
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.parentAuthorName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(viewModel.parentText)
                                        .font(.body)
                                        .lineLimit(3)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                }

                // リポスト情報
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

                // ヘッダー: アバター + 著者情報
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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // 本文テキスト
                Text(viewModel.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // 引用ポスト
                if let quoted = viewModel.quotedPost {
                    QuotePostCard(quoted: quoted)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                // 画像
                if !viewModel.embeddedImages.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(viewModel.embeddedImages, id: \.thumb) { embed in
                            let vm = AsyncImageViewModel(
                                url: embed.thumbUrl,
                                imageSize: .thumbnail,
                                alt: embed.alt,
                                fullSizeUrl: embed.fullsizeUrl
                            )
                            AsyncImageView(viewModel: vm)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // 動画
                if let video = viewModel.embeddedVideo {
                    VideoPlayerView(video: video)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                // リンクカード
                ForEach(viewModel.linkCards, id: \.uri) { externalLink in
                    LinkCardView(externalLink: externalLink)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                // 投稿時刻
                Text(viewModel.indexedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // アクションバー: リプライ・リポスト・いいね
                HStack(spacing: 0) {
                    Button(action: {
                        isShowingReplySheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                            Text("リプライ")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        Task { await viewModel.toggleLike() }
                    }) {
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

                    Button(action: {
                        Task { await viewModel.toggleRepost() }
                    }) {
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

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 16)

                // リプライ一覧セクション
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleRepliesExpansion()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.isRepliesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                Text("リプライ (\(viewModel.replies.count))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if viewModel.isRepliesExpanded {
                            Button(action: {
                                Task { await viewModel.fetchReplies() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if viewModel.isRepliesExpanded {
                        if viewModel.isFetchingReplies {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 24)
                                Spacer()
                            }
                        } else if viewModel.replies.isEmpty {
                            Text("リプライはありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(viewModel.replies) { reply in
                                Divider()
                                    .padding(.horizontal, 16)
                                NavigationLink(
                                    destination: PostDetailView(
                                        viewModel: PostDetailViewModel(post: reply.post)
                                    )
                                ) {
                                    ReplyItemView(threadViewPost: reply)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 80) // 戻るボタンと被らないよう余白
            }
        }
        // 右下の閉じるボタン（既存デザインパターン踏襲）
        .overlay(alignment: .bottomTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .scaleEffect(1.2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $isShowingReplySheet) {
            ReplyPostCardView(post: viewModel.post, isShowReplyCard: $isShowingReplySheet)
        }
        .onChange(of: isShowingReplySheet) { isShowing in
            if !isShowing {
                Task {
                    await viewModel.refreshRepliesAfterPost()
                }
            }
        }
    }
}
