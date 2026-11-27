import SwiftUI

struct ProfileView: View {
  @StateObject var viewModel: ProfileViewModel
  @State private var selectedTab = 0
  @State private var selectedPost: Post?
  @State private var showingMuteConfirm = false
  @State private var showingBlockConfirm = false
  @State private var showingUnfollowConfirm = false
  @State private var showingEditor = false
  @ObservedObject private var rtFilter = RTFilterManager.shared
  @ObservedObject private var highlightManager = UserHighlightManager.shared
  @State private var showingHighlightPicker = false
  @State private var selectedFollowItem: FollowDisplayItem?
  @State private var followersLoaded = false
  @State private var followingLoaded = false
  @State private var likesLoaded = false
  @Environment(\.dismiss) private var dismiss

  /// ナビゲーションバーとステータスバーの高さ。ヘッダー画像をその下まで広げて、戻るボタンだけの隙間をなくす
  @State private var topInset: CGFloat = 0

  init(viewModel: ProfileViewModel) {
    self._viewModel = StateObject(wrappedValue: viewModel)
  }

  init() {
    self._viewModel = StateObject(
      wrappedValue: ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: [])))
  }

  private var tabs: [String] {
    var t = [
      String(localized: "ポスト"),
      String(localized: "フォロワー"),
      String(localized: "フォロー中"),
    ]
    if viewModel.isOwnProfile { t.append(String(localized: "いいね")) }
    return t
  }

  var body: some View {
    // ヘッダーごと 1 つの List にする。ヘッダーは流れ、切り替えボタンだけ上に残る。
    // List なので TL と同じスワイプ操作・引っ張って更新が効く
    List {
      Section { profileHeader }
      Section {
        tabContent
      } header: {
        tabStrip
      }
    }
    // ポストのアイコンから開くプロフィールも push で重ねる。「戻る」で 1 段ずつ確実に戻れる
    .environment(\.navigateToProfile) { actor in
      selectedFollowItem = FollowDisplayItem(
        did: actor, handle: actor, displayName: nil, avatar: nil)
    }
    .listStyle(.plain)
    .listSectionSpacing(0)
    .onGeometryChange(for: CGFloat.self, of: { $0.safeAreaInsets.top }) { topInset = $0 }
    .refreshable {
      await viewModel.fetchProfile()
      switch selectedTab {
      case 1: await viewModel.fetchFollowers()
      case 2: await viewModel.fetchFollowing()
      case 3: await viewModel.fetchLikedPosts()
      default: await viewModel.fetchPosts()
      }
    }
    .overlay {
      // 引っ張って更新のときは出さない（最初の読み込みだけ）
      if viewModel.isFetching && viewModel.profile.did.isEmpty {
        ProgressView()
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemBackground))
      }
    }
    .sheet(item: $selectedPost) { post in
      NavigationStack {
        // シートの一番下は戻るボタンも無く空のバーになるので隠す
        PostDetailView(viewModel: PostDetailViewModel(post: post))
          .toolbar(.hidden, for: .navigationBar)
      }
    }
    .sheet(isPresented: $showingEditor, onDismiss: { Task { await viewModel.fetchProfile() } }) {
      NavigationStack {
        List { ProfileEditCard(startExpanded: true) }
          .navigationTitle("プロフィールを編集")
          .navigationBarTitleDisplayMode(.inline)
      }
    }
    .navigationDestination(item: $selectedFollowItem) { item in
      ProfileView(
        viewModel: ProfileViewModel(
          actor: item.handle, profile: .init(did: "", handle: "", labels: []))
      )
    }
    .sheet(isPresented: $showingHighlightPicker) {
      HighlightColorPickerView(
        did: viewModel.profile.did,
        authorName: viewModel.profile.displayName ?? viewModel.profile.handle
      )
      .presentationDetents([.height(280)])
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
    .alert("\(viewModel.profile.handle) のフォローを解除しますか？", isPresented: $showingUnfollowConfirm) {
      Button("フォロー解除", role: .destructive) {
        Task { await viewModel.toggleFollow() }
      }
      Button("キャンセル", role: .cancel) {}
    }
    .alert(
      "プロフィールを読み込めませんでした",
      isPresented: Binding(
        get: { viewModel.loadErrorMessage != nil },
        set: { if !$0 { viewModel.loadErrorMessage = nil } })
    ) {
      Button("OK") { dismiss() }
    } message: {
      Text(viewModel.loadErrorMessage ?? "")
    }
    .onChange(of: selectedTab) { _, tab in
      lazyLoadTab(tab)
    }
    .task {
      await viewModel.fetchProfile()
      await viewModel.fetchPosts()
    }
  }

  // MARK: - Profile header

  /// 設定の ProfileEditCard と同じ並び（ヘッダー画像・丸アイコン・名前・@handle · 代名詞・自己紹介・リンクの行）
  @ViewBuilder private var profileHeader: some View {
    if let banner = viewModel.profile.banner.flatMap(URL.init(string:)) {
      CachedAsyncImage(url: banner) {
        $0.resizable().scaledToFill()
      } placeholder: {
        Color(.systemGray5)
      }
      .frame(height: 100 + topInset)
      .frame(maxWidth: .infinity)
      .clipped()
      .padding(.top, -topInset)
      .listRowInsets(EdgeInsets())
      .listRowSeparator(.hidden)
    }

    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Group {
          if let avatarUrl = viewModel.profile.avatar.flatMap(URL.init(string:)) {
            CachedAsyncImage(url: avatarUrl) { image in
              image.resizable().scaledToFill()
            } placeholder: {
              Color(.systemGray5)
            }
          } else {
            Color(.systemGray5)
          }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(
            viewModel.profile.displayName.flatMap { $0.isEmpty ? nil : $0 }
              ?? viewModel.profile.handle
          )
          .font(.headline)
          .lineLimit(1)
          Text(
            [("@" + viewModel.profile.handle), viewModel.profile.pronouns].compactMap {
              $0?.isEmpty == false ? $0 : nil
            }.joined(separator: " · ")
          )
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          if viewModel.profile.viewer?.followedBy != nil {
            Text("フォローされています")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        Spacer()
        if viewModel.isOwnProfile {
          Button("編集") { showingEditor = true }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        } else {
          followButton
          actionMenu
        }
      }

      if let description = viewModel.profile.description, !description.isEmpty {
        Text(linkified(description))
          .font(.subheadline)
      }

      // リンクは 1 行のカプセル型ボタンにまとめ、ヘッダーを低く保つ（多ければ横に流れる）
      if let links = viewModel.profile.links, !links.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(links, id: \.self) { link in
              if let url = URL(string: link.url) {
                Link(destination: url) {
                  HStack(spacing: 4) {
                    if let icon = link.icon.flatMap(URL.init(string:)) {
                      CachedAsyncImage(url: icon) {
                        $0.resizable().scaledToFit()
                      } placeholder: {
                        Image(systemName: "link")
                      }
                      .frame(width: 14, height: 14)
                      .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                      Image(systemName: "link")
                    }
                    Text(link.title.flatMap { $0.isEmpty ? nil : $0 } ?? url.host() ?? link.url)
                      .lineLimit(1)
                  }
                  .font(.subheadline)
                  .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
              }
            }
          }
        }
        // 行の余白で切らず画面の端まで流す。端で途切れたボタンが「横に続きがある」目印になる
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
      }

    }
    // 1 つの行に複数のボタン（リンク・メニュー・フォロー）があるので、行全体ではなくそれぞれが反応するようにする
    .buttonStyle(.borderless)
    .listRowSeparator(.hidden)
    // TL と同じ背景色を敷き、「この人＝この色」を画面をまたいで続ける
    .listRowBackground(highlightManager.color(for: viewModel.profile.did)?.opacity(0.12))
  }

  /// フォロー中は控えめに。うっかり外さないよう、解除だけ確認を挟む
  @ViewBuilder private var followButton: some View {
    if viewModel.isFollowing {
      Button("フォロー中") { showingUnfollowConfirm = true }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(viewModel.isProcessingFollow)
    } else {
      Button("フォロー") { Task { await viewModel.toggleFollow() } }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(viewModel.isProcessingFollow || viewModel.isBlocked)
    }
  }

  /// ミュート・RT 非表示・ブロックをまとめたメニュー（twicca のユーザー画面のメニューに相当）
  private var actionMenu: some View {
    Menu {
      Button(
        viewModel.isMuted ? "ミュートを解除" : "ミュート",
        systemImage: viewModel.isMuted ? "speaker.wave.2" : "speaker.slash"
      ) { showingMuteConfirm = true }
      // TL と同じ背景色。プロフィールのヘッダーにも出るので、ここで決めるのが分かりやすい
      Button("背景色を設定", systemImage: "paintpalette") { showingHighlightPicker = true }
      if rtFilter.filteredDIDs.contains(viewModel.profile.did) {
        Button("リポストを表示", systemImage: "arrow.2.squarepath") {
          rtFilter.remove(did: viewModel.profile.did)
        }
      } else {
        Button("リポストを非表示", systemImage: "arrow.2.squarepath") {
          rtFilter.add(
            did: viewModel.profile.did,
            displayName: viewModel.profile.displayName ?? viewModel.profile.handle,
            handle: viewModel.profile.handle,
            avatarUrl: viewModel.profile.avatar.flatMap(URL.init(string:)))
        }
      }
      Button(
        viewModel.isBlocked ? "ブロックを解除" : "ブロック",
        systemImage: viewModel.isBlocked ? "xmark.shield.fill" : "xmark.shield",
        role: viewModel.isBlocked ? nil : .destructive
      ) { showingBlockConfirm = true }
    } label: {
      Image(systemName: "ellipsis.circle")
        .font(.title3)
        .foregroundColor(.secondary)
    }
    .buttonStyle(.borderless)
    .disabled(viewModel.isProcessingMuteBlock)
    .accessibilityLabel("その他の操作")
  }

  /// 自己紹介の URL をタップで開けるようにする
  private func linkified(_ text: String) -> AttributedString {
    var string = AttributedString(text)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return string }
    for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let url = match.url, let stringRange = Range(match.range, in: text),
        let range = Range(stringRange, in: string)
      else { continue }
      string[range].link = url
    }
    return string
  }

  // MARK: - Tab strip

  private var tabCounts: [Int?] {
    [
      viewModel.profile.postsCount, viewModel.profile.followersCount,
      viewModel.profile.followsCount,
    ]
  }

  private var tabStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      // 代名詞の選択と同じカプセル型のボタンで切り替える
      HStack(spacing: 8) {
        ForEach(Array(tabs.enumerated()), id: \.element) { index, name in
          Button {
            selectedTab = index
          } label: {
            // 数は切り替えボタンに入れて、ヘッダーを 1 行短くする（いいねは数が取れないので名前だけ）
            HStack(spacing: 4) {
              Text(name)
              if index < tabCounts.count, let count = tabCounts[index] {
                Text(count.formatted()).monospacedDigit()
              }
            }
          }
          .font(.subheadline.weight(selectedTab == index ? .semibold : .regular))
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(selectedTab == index ? .accentColor : .secondary)
          .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .listRowInsets(EdgeInsets())
    .background(Color(.systemBackground))
    .textCase(nil)
  }

  // MARK: - Tab content

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case 1:
      followRows(
        items: viewModel.followers.map {
          FollowDisplayItem(
            did: $0.did, handle: $0.handle, displayName: $0.displayName, avatar: $0.avatar)
        },
        isLoading: viewModel.isFetchingFollowers,
        emptyMessage: "フォロワーがいません",
        hasMore: viewModel.followersCursor != nil,
        loadMore: { Task { await viewModel.fetchFollowers(loadMore: true) } })
    case 2:
      followRows(
        items: viewModel.following.map {
          FollowDisplayItem(
            did: $0.did, handle: $0.handle, displayName: $0.displayName, avatar: $0.avatar)
        },
        isLoading: viewModel.isFetchingFollowing,
        emptyMessage: "フォロー中のユーザーがいません",
        hasMore: viewModel.followingCursor != nil,
        loadMore: { Task { await viewModel.fetchFollowing(loadMore: true) } })
    case 3:
      feedRows(
        items: viewModel.likedPosts,
        isLoading: viewModel.isFetchingLikes,
        emptyMessage: "いいねしたポストがありません",
        hasMore: viewModel.likesCursor != nil,
        loadMore: { Task { await viewModel.fetchLikedPosts(loadMore: true) } })
    default:
      postFilterRow
      feedRows(
        items: viewModel.posts,
        isLoading: viewModel.isFetchingPosts,
        emptyMessage: "投稿がありません",
        hasMore: viewModel.postsCursor != nil,
        loadMore: { Task { await viewModel.fetchPosts(loadMore: true) } })
    }
  }

  /// 既定は返信を除く。返信が多い人でも本人の発言が読める
  private var postFilterRow: some View {
    HStack(spacing: 8) {
      ForEach(ProfileViewModel.PostFilter.allCases, id: \.self) { filter in
        Button {
          guard viewModel.postFilter != filter else { return }
          viewModel.postFilter = filter
          Task { await viewModel.refreshPosts() }
        } label: {
          Text(filter.label)
        }
        .font(.caption.weight(viewModel.postFilter == filter ? .semibold : .regular))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(viewModel.postFilter == filter ? .accentColor : .secondary)
        .accessibilityAddTraits(viewModel.postFilter == filter ? .isSelected : [])
      }
    }
    .padding(.horizontal, 16)
    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
    .listRowSeparator(.hidden)
  }

  private func lazyLoadTab(_ tab: Int) {
    switch tab {
    case 1:
      if !followersLoaded {
        followersLoaded = true
        Task { await viewModel.fetchFollowers() }
      }
    case 2:
      if !followingLoaded {
        followingLoaded = true
        Task { await viewModel.fetchFollowing() }
      }
    case 3:
      if !likesLoaded {
        likesLoaded = true
        Task { await viewModel.fetchLikedPosts() }
      }
    default: break
    }
  }

  // MARK: - Shared rows

  @ViewBuilder
  private func statusRow(isLoading: Bool, isEmpty: Bool, emptyMessage: LocalizedStringKey)
    -> some View
  {
    if isLoading {
      ProgressView()
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
    } else if isEmpty {
      Text(emptyMessage)
        .foregroundColor(.secondary)
        .listRowSeparator(.hidden)
    }
  }

  /// TL と同じカード。List の行なのでスワイプ操作も TL と同じく効く。最後まで来たら続きを読む
  @ViewBuilder
  private func feedRows(
    items: [FeedItem], isLoading: Bool, emptyMessage: LocalizedStringKey, hasMore: Bool,
    loadMore: @escaping () -> Void
  ) -> some View {
    ForEach(items, id: \.post?.uri) { feedItem in
      if let post = feedItem.post {
        TimelineCardView(
          viewModel: TimelineCardViewModel(
            post: post, reason: feedItem.reason, reply: feedItem.reply)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedPost = post }
        .listRowInsets(EdgeInsets())
        .onAppear {
          if feedItem.post?.uri == items.last?.post?.uri && hasMore && !isLoading { loadMore() }
        }
      }
    }
    statusRow(isLoading: isLoading, isEmpty: items.isEmpty, emptyMessage: emptyMessage)
  }

  @ViewBuilder
  private func followRows(
    items: [FollowDisplayItem], isLoading: Bool, emptyMessage: LocalizedStringKey, hasMore: Bool,
    loadMore: @escaping () -> Void
  ) -> some View {
    ForEach(items) { item in
      Button {
        selectedFollowItem = item
      } label: {
        FollowListView.FollowItemRow(
          handle: item.handle, displayName: item.displayName, avatar: item.avatar)
      }
      .buttonStyle(.plain)
      .onAppear {
        if item.did == items.last?.did && hasMore && !isLoading { loadMore() }
      }
    }
    statusRow(isLoading: isLoading, isEmpty: items.isEmpty, emptyMessage: emptyMessage)
  }
}

// MARK: - FollowDisplayItem

private struct FollowDisplayItem: Identifiable, Hashable {
  let did: String
  let handle: String
  let displayName: String?
  let avatar: String?
  var id: String { did }
}

#Preview {
  ProfileView()
}
