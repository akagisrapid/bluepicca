import SwiftUI

struct ProfileView: View {
  @StateObject var viewModel: ProfileViewModel
  @State private var selectedTab = 0
  @State private var selectedPost: Post?
  @State private var showingPostDetail = false
  @State private var showingMuteConfirm = false
  @State private var showingBlockConfirm = false
  @State private var selectedFollowItem: FollowDisplayItem?
  @State private var followersLoaded = false
  @State private var followingLoaded = false
  @State private var likesLoaded = false
  @Environment(\.dismiss) private var dismiss

  init(viewModel: ProfileViewModel) {
    self._viewModel = StateObject(wrappedValue: viewModel)
  }

  init() {
    self._viewModel = StateObject(
      wrappedValue: ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: [])))
  }

  private var tabs: [String] {
    var t = ["概要", "投稿", "フォロワー", "フォロー中"]
    if viewModel.isOwnProfile { t.append("いいね") }
    return t
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
          tabStrip
          tabContent
        }
      }

    }
    .sheet(isPresented: $showingPostDetail) {
      if let post = selectedPost {
        NavigationStack {
          PostDetailView(viewModel: PostDetailViewModel(post: post))
        }
      }
    }
    .sheet(item: $selectedFollowItem) { item in
      ProfileView(
        viewModel: ProfileViewModel(
          actor: item.handle, profile: .init(did: "", handle: "", labels: [])))
    }
    .alert(
      viewModel.isMuted ? "ミュートを解除しますか？" : "\(viewModel.profile.handle) をミュートしますか？",
      isPresented: $showingMuteConfirm
    ) {
      Button(viewModel.isMuted ? "解除" : "ミュート", role: viewModel.isMuted ? .none : .destructive) {
        Task { await viewModel.toggleMute() }
      }
      Button("キャンセル", role: .cancel) {}
    }
    .alert(
      viewModel.isBlocked ? "ブロックを解除しますか？" : "\(viewModel.profile.handle) をブロックしますか？",
      isPresented: $showingBlockConfirm
    ) {
      Button(viewModel.isBlocked ? "解除" : "ブロック", role: viewModel.isBlocked ? .none : .destructive)
      {
        Task { await viewModel.toggleBlock() }
      }
      Button("キャンセル", role: .cancel) {}
    }
    .onChange(of: selectedTab) { _, tab in
      lazyLoadTab(tab)
    }
  }

  // MARK: - Profile header

  private var profileHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        if let avatarUrl = viewModel.profile.avatar {
          CachedAsyncImage(url: URL(string: avatarUrl)) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
          }
          .frame(width: 52, height: 52)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 52, height: 52)
        }

        VStack(alignment: .leading, spacing: 4) {
          if let displayName = viewModel.profile.displayName, !displayName.isEmpty {
            Text(displayName).font(.headline)
          }
          Text("@\(viewModel.profile.handle)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        Spacer()
      }

      HStack(spacing: 20) {
        VStack(spacing: 2) {
          Text("\(viewModel.profile.followsCount ?? 0)").font(.headline)
          Text("フォロー中").font(.caption).foregroundColor(.secondary)
        }
        .fixedSize()
        VStack(spacing: 2) {
          Text("\(viewModel.profile.followersCount ?? 0)").font(.headline)
          Text("フォロワー").font(.caption).foregroundColor(.secondary)
        }
        .fixedSize()
        VStack(spacing: 2) {
          Text("\(viewModel.profile.postsCount ?? 0)").font(.headline)
          Text("投稿").font(.caption).foregroundColor(.secondary)
        }
        .fixedSize()
        if !viewModel.isOwnProfile {
          Spacer()
          Button {
            showingMuteConfirm = true
          } label: {
            Image(systemName: viewModel.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
              .font(.title3)
              .foregroundColor(viewModel.isMuted ? .secondary : .orange)
          }
          .buttonStyle(.plain)
          Button {
            showingBlockConfirm = true
          } label: {
            Image(systemName: viewModel.isBlocked ? "xmark.shield.fill" : "xmark.shield")
              .font(.title3)
              .foregroundColor(viewModel.isBlocked ? .secondary : .red)
          }
          .buttonStyle(.plain)
        }
      }
      .disabled(viewModel.isProcessingMuteBlock)
      .opacity(viewModel.isProcessingMuteBlock ? 0.5 : 1)

      if !viewModel.isOwnProfile {
        Button(action: { Task { await viewModel.toggleFollow() } }) {
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
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
  }

  // MARK: - Tab strip

  private var tabStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 0) {
        ForEach(Array(tabs.enumerated()), id: \.offset) { index, name in
          ProfileTabButton(name: name, isSelected: selectedTab == index) {
            selectedTab = index
          }
        }
      }
    }
    .background(.bar)
  }

  // MARK: - Tab content

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case 0: overviewTab
    case 1: postsTab
    case 2: followersTab
    case 3: followingTab
    case 4: likesTab
    default: overviewTab
    }
  }

  private func lazyLoadTab(_ tab: Int) {
    switch tab {
    case 2:
      if !followersLoaded {
        followersLoaded = true
        Task { await viewModel.fetchFollowers() }
      }
    case 3:
      if !followingLoaded {
        followingLoaded = true
        Task { await viewModel.fetchFollowing() }
      }
    case 4:
      if !likesLoaded {
        likesLoaded = true
        Task { await viewModel.fetchLikedPosts() }
      }
    default: break
    }
  }

  // MARK: - Tabs

  private var overviewTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if let description = viewModel.profile.description, !description.isEmpty {
          Text(description)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

          let urls = extractUrls(from: description)
          if !urls.isEmpty {
            VStack(spacing: 8) {
              ForEach(urls, id: \.self) { url in
                LinkCardView(uri: url)
              }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
          }

          Divider()
        }
      }
      .padding(.top, 8)
    }
  }

  private func extractUrls(from text: String) -> [String] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else {
      return []
    }
    let range = NSRange(text.startIndex..., in: text)
    return detector.matches(in: text, range: range).compactMap { $0.url?.absoluteString }
  }

  private var postsTab: some View {
    feedListView(
      items: viewModel.posts,
      isLoading: viewModel.isFetchingPosts,
      emptyMessage: "投稿がありません",
      cursor: viewModel.postsCursor,
      loadMore: { Task { await viewModel.fetchPosts(loadMore: true) } }
    )
  }

  private var followersTab: some View {
    followList(
      items: viewModel.followers.map {
        FollowDisplayItem(
          did: $0.did, handle: $0.handle, displayName: $0.displayName, avatar: $0.avatar)
      },
      isLoading: viewModel.isFetchingFollowers,
      emptyMessage: "フォロワーがいません",
      hasMore: viewModel.followersCursor != nil,
      loadMore: { Task { await viewModel.fetchFollowers(loadMore: true) } }
    )
  }

  private var followingTab: some View {
    followList(
      items: viewModel.following.map {
        FollowDisplayItem(
          did: $0.did, handle: $0.handle, displayName: $0.displayName, avatar: $0.avatar)
      },
      isLoading: viewModel.isFetchingFollowing,
      emptyMessage: "フォロー中のユーザーがいません",
      hasMore: viewModel.followingCursor != nil,
      loadMore: { Task { await viewModel.fetchFollowing(loadMore: true) } }
    )
  }

  private var likesTab: some View {
    feedListView(
      items: viewModel.likedPosts,
      isLoading: viewModel.isFetchingLikes,
      emptyMessage: "いいねしたポストがありません",
      cursor: viewModel.likesCursor,
      loadMore: { Task { await viewModel.fetchLikedPosts(loadMore: true) } }
    )
  }

  // MARK: - Shared list views

  private func feedListView(
    items: [FeedItem],
    isLoading: Bool,
    emptyMessage: String,
    cursor: String?,
    loadMore: @escaping () -> Void
  ) -> some View {
    ScrollView {
      if isLoading && items.isEmpty {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .padding()
      } else if items.isEmpty {
        Text(emptyMessage)
          .foregroundColor(.gray)
          .padding()
      } else {
        LazyVStack(spacing: 0) {
          ForEach(items, id: \.post?.uri) { feedItem in
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
              Divider().padding(.horizontal)
            }
          }
          if cursor != nil {
            Button(action: loadMore) {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle())
                  .padding()
              } else {
                Text("さらに読み込む")
                  .foregroundColor(.blue)
                  .padding()
              }
            }
            .disabled(isLoading)
          }
        }
      }
    }
  }

  private func followList(
    items: [FollowDisplayItem],
    isLoading: Bool,
    emptyMessage: String,
    hasMore: Bool,
    loadMore: @escaping () -> Void
  ) -> some View {
    List {
      if isLoading && items.isEmpty {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
        .listRowSeparator(.hidden)
      } else if items.isEmpty && !isLoading {
        Text(emptyMessage)
          .foregroundColor(.gray)
          .listRowSeparator(.hidden)
      } else {
        ForEach(items) { item in
          Button {
            selectedFollowItem = item
          } label: {
            FollowListView.FollowItemRow(
              handle: item.handle, displayName: item.displayName, avatar: item.avatar)
          }
          .buttonStyle(.plain)
          .onAppear {
            if item.did == items.last?.did && hasMore {
              loadMore()
            }
          }
        }
        if isLoading {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowSeparator(.hidden)
        }
      }
    }
    .listStyle(.plain)
  }
}

// MARK: - FollowDisplayItem

private struct FollowDisplayItem: Identifiable {
  let did: String
  let handle: String
  let displayName: String?
  let avatar: String?
  var id: String { did }
}

// MARK: - ProfileTabButton

private struct ProfileTabButton: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 0) {
        Text(name)
          .font(.subheadline)
          .fontWeight(isSelected ? .semibold : .regular)
          .foregroundColor(isSelected ? .primary : .secondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
        Rectangle()
          .fill(isSelected ? Color.accentColor : Color.clear)
          .frame(height: 2)
      }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  ProfileView()
}
