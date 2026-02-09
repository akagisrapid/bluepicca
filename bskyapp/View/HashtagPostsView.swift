import SwiftUI

struct HashtagPostsView: View {
    @StateObject var viewModel: HashtagPostsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Text("#\(viewModel.hashtag)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        Button("更新", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.fetchPosts()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemBackground))

                    if viewModel.isFetching {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(2.0)
                        Spacer()
                    } else {
                        List(viewModel.posts, id: \.uri) { post in
                            NavigationLink(
                                destination: PostDetailView(
                                    viewModel: PostDetailViewModel(post: post)
                                )
                            ) {
                                HashtagPostRow(post: post)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationBarHidden(true)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            viewModel.isShowPostCard = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text("#\(viewModel.hashtag) で投稿")
                            }
                        }
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .scaleEffect(1.2)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchPosts()
            }
        }
        .sheet(isPresented: $viewModel.isShowPostCard) {
            PostCardView(
                viewModel: PostCardViewModel(text: "#\(viewModel.hashtag) "),
                isShowPostCard: $viewModel.isShowPostCard
            )
        }
    }

    struct HashtagPostRow: View {
        let post: Post

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProfileImageView(
                        viewModel: AsyncImageViewModel(
                            url: post.author?.avatarUrl,
                            imageSize: .avatar,
                            alt: post.author?.displayName ?? post.author?.handle ?? ""
                        ),
                        actor: post.author?.did ?? ""
                    )
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author?.displayName ?? post.author?.handle ?? "")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("@\(post.author?.handle ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if let text = post.record?.text {
                    Text(text)
                        .font(.body)
                        .lineLimit(4)
                        .padding(.leading, 48)
                }

                HStack {
                    Spacer()
                    if let likeCount = post.likeCount {
                        HStack(spacing: 2) {
                            Image(systemName: "star")
                                .font(.caption)
                            Text("\(likeCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
