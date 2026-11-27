import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @StateObject var viewModel: ContentViewModel
  @Binding var isLoggedIn: Bool
  @ObservedObject private var toastManager = ToastManager.shared
  @ObservedObject private var mutedUsersManager = MutedUsersManager.shared
  @ObservedObject private var rtFilterManager = RTFilterManager.shared
  @ObservedObject private var muteWordManager = MuteWordManager.shared
  @ObservedObject private var languageFilterManager = LanguageFilterManager.shared
  @ObservedObject private var labelManager = ContentLabelManager.shared
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var isShowSettings = false
  @State private var isShowBookmarks = false
  @State private var isShowSearch = false
  @State private var selectedPostForLikes: Post?
  @State private var navigationTarget: Post?
  @State private var profileNavActor: String?
  @State private var scrollProxy: ScrollViewProxy? = nil
  /// 引っ張って更新中は List 自身のインジケーターが出るので、上部のバーは出さない
  @State private var isPullRefreshing = false
  @AppStorage("feedSelectorStyle") private var feedSelectorStyle: String = "dropdown"
  @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled: Bool = false
  @AppStorage("autoRefreshIntervalSeconds") private var autoRefreshIntervalSeconds: Int = 60
  @AppStorage("realtimeRefreshEnabled") private var realtimeRefreshEnabled: Bool = true

  var body: some View {
    NavigationStack {
      mainContent
        .navigationDestination(
          isPresented: Binding(
            get: { navigationTarget != nil },
            set: { if !$0 { navigationTarget = nil } })
        ) {
          if let post = navigationTarget {
            PostDetailView(viewModel: PostDetailViewModel(post: post))
          }
        }
        .navigationDestination(
          isPresented: Binding(
            get: { profileNavActor != nil },
            set: { if !$0 { profileNavActor = nil } })
        ) {
          if let actor = profileNavActor {
            ProfileView(
              viewModel: ProfileViewModel(
                actor: actor,
                profile: .init(did: "", handle: "", labels: [])))
          }
        }
        .environment(\.navigateToProfile, { actor in profileNavActor = actor })
        .overlay(alignment: .bottom) {
          ToastOverlay(toastManager: toastManager)
        }
        .sheet(isPresented: $viewModel.isShowPostCard) {
          PostCardView(
            viewModel: PostCardViewModel(text: ""), isShowPostCard: $viewModel.isShowPostCard
          )
          .padding()
          .background(.clear)
          .cornerRadius(10)
          .shadow(radius: 5)
          .padding()
        }
        .toolbar {
          leadingToolbarItem
          trailingToolbarItem
          bottomToolbarItems
        }
        .sheet(isPresented: $isShowReplies) { RepliesView(viewModel: RepliesViewModel()) }
        .sheet(isPresented: $isShowBookmarks) { BookmarksView() }
        .sheet(isPresented: $isShowSettings) { SettingsView(isLoggedIn: $isLoggedIn) }
        .sheet(isPresented: $isShowSearch) { SearchView() }
        .onChange(of: viewModel.targetScrollUri) { _, uri in
          guard let uri else { return }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { scrollProxy?.scrollTo(uri, anchor: .top) }
            viewModel.isRestoringPosition = false
          }
          viewModel.targetScrollUri = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            // 公式アプリで変えたミュートワードを戻ってきたときに反映する
            Task { await MuteWordManager.shared.syncFromServer() }
          }
          if newPhase == .background {
            viewModel.saveReadPosition(uri: viewModel.currentReadUri)
          } else if newPhase == .active,
            let lastFetch = viewModel.lastFetchDate,
            Date().timeIntervalSince(lastFetch) > 300
          {
            Task { try? await viewModel.fetchTimeline() }
          }
        }
        .task { await MuteWordManager.shared.syncFromServer() }
        .task(
          id:
            "\(autoRefreshEnabled)-\(autoRefreshIntervalSeconds)-\(realtimeRefreshEnabled)-\(viewModel.selectedTab.id)-\(scenePhase)"
        ) {
          guard autoRefreshEnabled, scenePhase == .active else { return }
          // リアルタイム更新がオンなら、ホームはフォロー中の人の新着が来たときだけ取り直す。
          // オフのとき・ほかのフィード・フォロー一覧を取れなかったときは一定間隔で取り直す
          if realtimeRefreshEnabled, viewModel.selectedTab.id == FeedTab.home.id {
            // 更新間隔はホーム以外のもの。リアルタイムは合図が続いても 10 秒に1回までにまとめる
            await viewModel.refreshOnJetstreamEvents(minInterval: 10)
          }
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(autoRefreshIntervalSeconds))
            guard !Task.isCancelled else { continue }
            try? await viewModel.fetchNewer()
          }
        }
        // 開いている間も新着の返信などを通知で知らせる（設定で通知がオフなら何もしない）
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          // 端末トークンやミュート設定が変わっていればプッシュの登録を更新する
          await PushRegistrationService.shared.refresh()
          while !Task.isCancelled {
            await LocalNotificationService.shared.checkForNewNotifications()
            try? await Task.sleep(for: .seconds(120))
          }
        }
        .alert(
          "エラー",
          isPresented: Binding(
            get: { viewModel.feedError != nil },
            set: { if !$0 { viewModel.feedError = nil } }
          )
        ) {
          Button("OK") { viewModel.feedError = nil }
        } message: {
          Text(viewModel.feedError ?? "")
        }
    }
  }

  // MARK: - Main content

  @ViewBuilder
  private var mainContent: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(Array(viewModel.validFeeds.enumerated()), id: \.element.id) { index, feedItem in
          let prevItem = index > 0 ? viewModel.validFeeds[index - 1] : nil
          let connectsAbove =
            prevItem.map { TimelineCardViewModel.isThreadConnected(above: $0, below: feedItem) }
            ?? false
          feedRow(feedItem, connectsToCardAbove: connectsAbove)
        }
        if viewModel.isLoadingMore {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .listRowSeparator(.hidden)
        }
      }
      .listStyle(.plain)
      .refreshable {
        isPullRefreshing = true
        defer { isPullRefreshing = false }
        do {
          try await viewModel.fetchTimeline()
        } catch {
          dlog("Error refreshing timeline: \(error)")
        }
      }
      .onAppear { scrollProxy = proxy }
      .modifier(
        FeedTabStripModifier(
          show: feedSelectorStyle == "tabs" && viewModel.feedTabs.count > 1,
          strip: feedTabStrip
        ))
    }
    .overlay {
      if viewModel.validFeeds.isEmpty && viewModel.isFetchingTimeline {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .scaleEffect(1.5)
      }
    }
    .overlay(alignment: .top) {
      if viewModel.isFetchingTimeline && !viewModel.validFeeds.isEmpty && !isPullRefreshing {
        ProgressView()
          .progressViewStyle(LinearProgressViewStyle())
          .tint(.accentColor)
      } else if viewModel.unreadCount > 0 {
        // 件数はツールバーに出せない（ツールバーのボタンはアイコンへの重ね描きもバッジも描かない）
        Button(action: scrollToNewest) {
          SwiftUI.Label("\(viewModel.unreadCount)件の新着", systemImage: "arrow.up")
            .font(.footnote.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: Capsule())
        }
        .padding(.top, 8)
      }
    }
  }

  /// 取っておいた新着も足してから一番上へ
  private func scrollToNewest() {
    viewModel.showNewest()
    let firstId = viewModel.validFeeds.first.map { $0.post?.uri ?? $0.id }
    // 新着を足した直後は List の並べ直しが終わっていないので、次の描画で動かす
    DispatchQueue.main.async {
      withAnimation { scrollProxy?.scrollTo(firstId, anchor: .top) }
    }
  }

  @ViewBuilder
  private func feedRow(
    _ feedItem: FeedItem, connectsToCardAbove: Bool = false
  ) -> some View {
    if let post = feedItem.post {
      let cardVM = TimelineCardViewModel(
        post: post, reason: feedItem.reason, reply: feedItem.reply,
        connectsToCardAbove: connectsToCardAbove)
      TimelineCardView(viewModel: cardVM)
        .contentShape(Rectangle())
        .onTapGesture { navigationTarget = post }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .id(post.uri ?? feedItem.id)
        .onAppear {
          if let uri = post.uri { viewModel.cellDidAppear(uri: uri) }
          if feedItem.id == viewModel.validFeeds.last?.id {
            Task { await viewModel.loadMore() }
          }
        }
        .onDisappear {
          if let uri = post.uri { viewModel.cellDidDisappear(uri: uri) }
        }
    }
  }

  // MARK: - Tab strip

  @ViewBuilder
  private var tabStripIfNeeded: some View {
    if feedSelectorStyle == "tabs" && viewModel.feedTabs.count > 1 {
      feedTabStrip
    }
  }

  private var feedTabStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 0) {
        ForEach(viewModel.feedTabs) { tab in
          UnderlineTabButton(
            name: tab.name,
            isSelected: viewModel.selectedTab.id == tab.id,
            action: { viewModel.selectTab(tab) }
          )
        }
      }
    }
    .background(.bar)
  }

  // MARK: - Toolbar items

  @ToolbarContentBuilder
  private var leadingToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      if feedSelectorStyle == "dropdown" && viewModel.isLoadingFeedTabs {
        ProgressView().scaleEffect(0.8)
      } else if feedSelectorStyle == "dropdown" && viewModel.feedTabs.count > 1 {
        Picker(
          selection: Binding(
            get: { viewModel.selectedTab.id },
            set: { id in
              if let tab = viewModel.feedTabs.first(where: { $0.id == id }) {
                viewModel.selectTab(tab)
              }
            }
          ), label: Image(systemName: "list.bullet")
        ) {
          ForEach(viewModel.feedTabs) { tab in
            Text(tab.name).tag(tab.id)
          }
        }
        .pickerStyle(.menu)
      } else if feedSelectorStyle == "tabs" {
        Text(viewModel.selectedTab.name).font(.headline)
      } else {
        Image(systemName: "list.bullet")
      }
    }
  }

  /// メモリ上のセッションは起動直後や 429 の後に空になるので、DID は必要なら取り直す
  private func showMyProfile() {
    Task {
      do {
        profileNavActor = try await SessionManager.shared.getSession().did
      } catch {
        toastManager.show(
          icon: "exclamationmark.triangle", text: String(localized: "プロフィールを開けませんでした"))
      }
    }
  }

  @ToolbarContentBuilder
  private var trailingToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: showMyProfile) {
        SwiftUI.Label("プロフィール", systemImage: "person.circle").labelStyle(.iconOnly)
      }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { isShowSearch = true }) {
        SwiftUI.Label("検索", systemImage: "magnifyingglass").labelStyle(.iconOnly)
      }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { isShowSettings = true }) {
        SwiftUI.Label("設定", systemImage: "gearshape").labelStyle(.iconOnly)
      }
    }
  }

  @ToolbarContentBuilder
  private var bottomToolbarItems: some ToolbarContent {
    ToolbarItemGroup(placement: .bottomBar) {
      Button("Post", systemImage: "square.and.pencil") {
        withAnimation(.easeInOut(duration: 0.3)) {
          viewModel.isShowPostCard.toggle()
        }
      }
      Button("Replies", systemImage: "bubble.left.and.bubble.right") {
        isShowReplies = true
      }
      Button("Bookmarks", systemImage: "bookmark") {
        isShowBookmarks = true
      }
      Spacer()
      Button("Top", systemImage: "arrow.up.to.line") { scrollToNewest() }
      Button("更新", systemImage: "arrow.clockwise") {
        Task {
          do {
            try await viewModel.fetchTimeline()
          } catch {
            dlog("Error fetching timeline: \(error)")
          }
        }
      }
    }
  }
}

// MARK: - Feed tab strip modifier

private struct FeedTabStripModifier<Strip: View>: ViewModifier {
  let show: Bool
  let strip: Strip

  func body(content: Content) -> some View {
    if show {
      content.safeAreaInset(edge: .top, spacing: 0) { strip }
    } else {
      content
    }
  }
}

#Preview {
  var vm = ContentViewModel()
  return ContentView(viewModel: vm, isLoggedIn: .constant(true))
}
