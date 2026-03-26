import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    @StateObject var asyncImageViewModel: AsyncImageViewModel
    @State private var showingFollowsList = false
    @State private var showingFollowersList = false
    @State private var selectedPost: Post?
    @State private var showingPostDetail = false
    @State private var showingMuteBlockMenu = false
    @State private var showingMuteBlockList = false
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._asyncImageViewModel = StateObject(wrappedValue: AsyncImageViewModel(url: nil, imageSize: .avatar, alt: ""))
    }
    
    init() {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: [])))
        self._asyncImageViewModel = StateObject(wrappedValue: AsyncImageViewModel(url: nil, imageSize: .avatar, alt: ""))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isFetching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
            } else {
                    ScrollView {
                        VStack(alignment: .leading){
                            HStack{
                                AsyncImageView(viewModel: asyncImageViewModel)
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
                
                // オーバーレイボタン群
                VStack {
                    HStack {
                        Spacer()
                        // ︙ メニューボタン（右上）
                        Button(action: { showingMuteBlockMenu = true }) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
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
        .sheet(isPresented: $showingMuteBlockList) {
            MuteBlockListView()
        }
        .overlay {
            if showingMuteBlockMenu {
                AccountActionMenu(
                    isMuted: viewModel.isMuted,
                    isBlocked: viewModel.isBlocked,
                    isProcessing: viewModel.isProcessingMuteBlock,
                    onMute: { Task { await viewModel.toggleMute() } },
                    onBlock: { Task { await viewModel.toggleBlock() } },
                    onShowList: { showingMuteBlockList = true },
                    onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showingMuteBlockMenu = false } }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.2), value: showingMuteBlockMenu)
    }
}

private struct AccountActionMenu: View {
    let isMuted: Bool
    let isBlocked: Bool
    let isProcessing: Bool
    let onMute: () -> Void
    let onBlock: () -> Void
    let onShowList: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Text("アカウント操作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)

                Divider()

                MenuButton(label: isMuted ? "ミュート解除" : "ミュート",
                           icon: isMuted ? "speaker.wave.2" : "speaker.slash",
                           color: .primary) {
                    onMute()
                    onDismiss()
                }

                Divider()

                MenuButton(label: isBlocked ? "ブロック解除" : "ブロック",
                           icon: isBlocked ? "hand.raised.slash" : "hand.raised",
                           color: isBlocked ? .primary : .red) {
                    onBlock()
                    onDismiss()
                }

                Divider()

                MenuButton(label: "ミュート・ブロックリスト", icon: "list.bullet", color: .primary) {
                    onShowList()
                    onDismiss()
                }

                Divider()

                MenuButton(label: "キャンセル", icon: nil, color: .secondary) {
                    onDismiss()
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1)
        }
    }
}

private struct MenuButton: View {
    let label: String
    let icon: String?
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 20)
                }
                Text(label)
                Spacer()
            }
            .foregroundColor(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#Preview {
    ProfileView()
}
