import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    @State private var showingFollowsList = false
    @State private var showingFollowersList = false
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: [])))
    }

    private var avatarUrl: URL? {
        guard let avatar = viewModel.profile.avatar else { return nil }
        return URL(string: avatar)
    }
    
    var body: some View {
        ZStack {
            Group {
                if viewModel.isFetching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading){
                            HStack{
                                AsyncImage(url: avatarUrl) { image in
                                    image.image?
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 60, maxHeight: 60)
                                }
                                VStack(alignment: .leading){
                                    Text(viewModel.profile.handle)
                                        .font(.headline).padding()
                                    
                                    Text("\(viewModel.profile.postsCount ?? 0) posts").padding()
                                    
                                }
                            }
                            
                            Button(action: {
                                Task {
                                    await viewModel.toggleFollow()
                                }
                            }) {
                                Text(viewModel.isFollowing ? "フォロー解除" : "フォロー")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(viewModel.isFollowing ? Color.red : Color.blue)
                                    .cornerRadius(10)
                            }
                            .disabled(viewModel.isProcessingFollow)
                            .padding(.vertical, 5)
                            
                            HStack{
                                Image(systemName: "person.fill")
                                Text("Name")
                                    .padding()
                                Text(viewModel.profile.displayName ?? "none")
                            }
                            Button(action: {
                                showingFollowersList = true
                            }) {
                                HStack{
                                    Image(systemName: "person.2.fill")
                                    Text("Followers")
                                        .padding()
                                    Text("\(viewModel.profile.followersCount ?? 0)")
                                    Spacer()
                                }
                                .foregroundColor(.primary)
                            }
                            .sheet(isPresented: $showingFollowersList) {
                                FollowListView(actor: viewModel.profile.handle, listType: .followers)
                            }
                            
                            Button(action: {
                                showingFollowsList = true
                            }) {
                                HStack{
                                    Image(systemName: "person.2.fill")
                                    Text("Follows")
                                        .padding()
                                    Text("\(viewModel.profile.followsCount ?? 0)")
                                    Spacer()
                                }
                                .foregroundColor(.primary)
                            }
                            .sheet(isPresented: $showingFollowsList) {
                                FollowListView(actor: viewModel.profile.handle, listType: .follows)
                            }
                            HStack{
                                Image(systemName: "ellipsis.message.fill")
                                Text("Description").padding()
                            }
                            Text(viewModel.profile.description ?? "none")
                            
                            // ポスト一覧セクション
                            Divider()
                                .padding(.vertical, 10)
                            
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Posts")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    Task {
                                        await viewModel.refreshPosts()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                                .disabled(viewModel.isFetchingPosts)
                            }
                            .padding(.bottom, 5)
                            
                            if viewModel.isFetchingPosts && viewModel.posts.isEmpty {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding()
                            } else if viewModel.posts.isEmpty {
                                Text("投稿がありません")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.posts, id: \.post?.uri) { feedItem in
                                        if let post = feedItem.post {
                                            TimelineCardView(
                                                viewModel: TimelineCardViewModel(
                                                    post: post,
                                                    reason: feedItem.reason,
                                                    reply: feedItem.reply
                                                )
                                            )
                                            .onTapGesture {
                                                selectedPost = post
                                                showingPostDetail = true
                                            }
                                            .background(Color.clear)
                                            .contentShape(Rectangle())
                                            
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                    
                                    // 追加読み込みボタン
                                    if viewModel.postsCursor != nil {
                                        Button(action: {
                                            Task {
                                                await viewModel.fetchPosts()
                                            }
                                        }) {
                                            if viewModel.isFetchingPosts {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                                    .padding()
                                            } else {
                                                Text("さらに読み込む")
                                                    .foregroundColor(.blue)
                                                    .padding()
                                            }
                                        }
                                        .disabled(viewModel.isFetchingPosts)
                                    }
                                }
                            }
                            
                        }
                        .padding()
                    }
                }
                
                // 右下の戻るボタン
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
            .sheet(isPresented: $showingPostDetail) {
                if let post = selectedPost {
                    PostDetailView(viewModel: PostDetailViewModel(post: post))
                }
            }
        }
        .task {
            await viewModel.fetchProfile()
            await viewModel.fetchPosts()
        }
    }
}
#Preview {
    ProfileView()
}
