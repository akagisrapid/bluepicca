import SwiftUI

struct ReplyItemView: View {
    let threadViewPost: ThreadViewPost
    @ObservedObject private var post: Post
    @State private var isLiking = false
    @State private var isReposting = false
    @State private var hashtagSearchItem: HashtagSearchItem? = nil

    init(threadViewPost: ThreadViewPost) {
        self.threadViewPost = threadViewPost
        self._post = ObservedObject(wrappedValue: threadViewPost.post)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                ProfileImageView(
                    viewModel: AsyncImageViewModel(
                        url: post.author?.avatarUrl,
                        imageSize: .timeline,
                        alt: post.author?.displayName ?? post.author?.handle ?? ""
                    ),
                    actor: post.author?.did ?? ""
                )
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    // ユーザー情報
                    HStack {
                        Text(post.author?.displayName ?? post.author?.handle ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("@\(post.author?.handle ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let indexedAt = post.indexedAt,
                           let date = indexedAt.parseToDateRemovingMilliseconds {
                            Text(date.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 本文
                    if let text = post.record?.text, !text.isEmpty {
                        PostTextView(text: text) { tag in
                            hashtagSearchItem = HashtagSearchItem(query: tag)
                        }
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // 画像
                    if let images = post.embed?.images, !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(images, id: \.thumb) { image in
                                    AsyncImageView(
                                        viewModel: AsyncImageViewModel(
                                            url: image.thumbUrl,
                                            imageSize: .thumbnail,
                                            alt: image.alt,
                                            fullSizeUrl: image.fullsizeUrl
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // アクション
                    HStack(spacing: 20) {
                        Button(action: {
                            Task {
                                isLiking = true
                                await PostInteractionHelper.toggleLike(post: post)
                                isLiking = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: post.viewer?.like != nil ? "star.fill" : "star")
                                    .foregroundColor(post.viewer?.like != nil ? .yellow : .secondary)
                                    .font(.caption)
                                Text("\(post.likeCount ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLiking)
                        .opacity(isLiking ? 0.5 : 1.0)

                        Button(action: {
                            Task {
                                isReposting = true
                                await PostInteractionHelper.toggleRepost(post: post)
                                isReposting = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.rectanglepath")
                                    .foregroundColor(post.viewer?.repost != nil ? .green : .secondary)
                                    .font(.caption)
                                Text("\(post.repostCount ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isReposting)
                        .opacity(isReposting ? 0.5 : 1.0)

                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }

            // ネストしたリプライ（最大3件）
            if let nestedReplies = threadViewPost.replies, !nestedReplies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nestedReplies.prefix(3)) { nestedReply in
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 2)
                                .padding(.leading, 15)
                                .padding(.trailing, 12)
                            NavigationLink(
                                destination: PostDetailView(
                                    viewModel: PostDetailViewModel(post: nestedReply.post)
                                )
                            ) {
                                ReplyItemView(threadViewPost: nestedReply)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if nestedReplies.count > 3 {
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 2)
                                .padding(.leading, 15)
                                .padding(.trailing, 12)
                            Text("他 \(nestedReplies.count - 3) 件のリプライ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $hashtagSearchItem) { item in
            SearchView(initialQuery: item.query)
        }
    }
}
