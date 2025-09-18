import SwiftUI

struct LikesView: View {
    @StateObject var viewModel: LikesViewModel
    let postUri: String
    let postCid: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("いいね一覧を読み込み中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("再試行") {
                            Task {
                                await viewModel.fetchTargetPost(uri: postUri)
                                await viewModel.fetchLikes(uri: postUri, cid: postCid)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if viewModel.likes.isEmpty {
                    VStack {
                        Image(systemName: "heart")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("まだいいねがありません")
                            .foregroundColor(.gray)
                            .padding()
                    }
                } else {
                    List {
                        if let targetPost = viewModel.targetPost {
                            Section {
                                TimelineCardView(viewModel: TimelineCardViewModel(post: targetPost))
                            } header: {
                                Text("対象ポスト")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, -10)
                            }
                        }
                        
                        Section {
                            ForEach(viewModel.likes, id: \.actor.did) { like in
                                LikeItemView(like: like)
                            }
                        } header: {
                            Text("いいねしたユーザー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, -10)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("いいね一覧")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchTargetPost(uri: postUri)
                await viewModel.fetchLikes(uri: postUri, cid: postCid)
            }
        }
    }
}

struct LikeItemView: View {
    let like: Like
    
    var body: some View {
        HStack {
            AsyncImageView(viewModel: AsyncImageViewModel(url: like.actor.avatarUrl,imageSize: .timeline, alt: ""))
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(like.actor.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("@\(like.actor.handle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(formatDate(like.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "ja_JP")
        
        return displayFormatter.string(from: date)
    }
}

#Preview {
    LikesView(
        viewModel: LikesViewModel(),
        postUri: "at://example.com/app.bsky.feed.post/example",
        postCid: nil
    )
}
