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
    @State private var selectedTab = 0
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
                VStack(spacing: 0) {
                    profileHeader

                    Picker("", selection: $selectedTab) {
                        Text("概要").tag(0)
                        Text("投稿").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    TabView(selection: $selectedTab) {
                        overviewTab.tag(0)
                        postsTab.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }

            // オーバーレイボタン群
            VStack {
                HStack {
                    Spacer()
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

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImageView(viewModel: asyncImageViewModel)

                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = viewModel.profile.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.headline)
                    }
                    Text("@\(viewModel.profile.handle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.profile.postsCount ?? 0) posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button(action: {
                Task { await viewModel.toggleFollow() }
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let description = viewModel.profile.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    Divider()
                }

                Button(action: { showingFollowersList = true }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("フォロワー")
                            .padding(.leading, 4)
                        Spacer()
                        Text("\(viewModel.profile.followersCount ?? 0)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .sheet(isPresented: $showingFollowersList) {
                    FollowListView(actor: viewModel.profile.handle, listType: .followers)
                }

                Divider()

                Button(action: { showingFollowsList = true }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("フォロー中")
                            .padding(.leading, 4)
                        Spacer()
                        Text("\(viewModel.profile.followsCount ?? 0)")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .sheet(isPresented: $showingFollowsList) {
                    FollowListView(actor: viewModel.profile.handle, listType: .follows)
                }
            }
            .padding(.top, 8)
        }
    }

    private var postsTab: some View {
        ScrollView {
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

                    if viewModel.postsCursor != nil {
                        Button(action: {
                            Task { await viewModel.fetchPosts() }
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
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 8) {
                // アクションカード
                VStack(spacing: 0) {
                    Text("アカウント操作")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 14)

                    Divider()

                    MenuButton(label: isMuted ? "ミュート解除" : "ミュート",
                               color: .primary) {
                        onMute(); onDismiss()
                    }

                    Divider()

                    MenuButton(label: isBlocked ? "ブロック解除" : "ブロック",
                               color: isBlocked ? .primary : .red) {
                        onBlock(); onDismiss()
                    }

                    Divider()

                    MenuButton(label: "ミュート・ブロックリスト", color: .primary) {
                        onShowList(); onDismiss()
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // キャンセルカード
                MenuButton(label: "キャンセル", color: .primary, fontWeight: .semibold) {
                    onDismiss()
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1)
        }
    }
}

private struct MenuButton: View {
    let label: String
    let color: Color
    var fontWeight: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: fontWeight))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
}
