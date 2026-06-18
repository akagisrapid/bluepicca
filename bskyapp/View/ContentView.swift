import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @StateObject var viewModel: ContentViewModel
  @Binding var isLoggedIn: Bool
  @ObservedObject private var toastManager = ToastManager.shared
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var isShowSettings = false
  @State private var isShowBookmarks = false
  @State private var isShowSearch = false
  @State private var isShowMyProfile = false
  @State private var selectedPostForLikes: Post?
  @State private var scrollProxy: ScrollViewProxy? = nil
  @AppStorage("feedSelectorStyle") private var feedSelectorStyle: String = "dropdown"
  @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled: Bool = false
  @AppStorage("autoRefreshIntervalSeconds") private var autoRefreshIntervalSeconds: Int = 60

  var body: some View {
    NavigationStack {
      mainContent
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
        .sheet(isPresented: $isShowMyProfile) {
          if let did = SessionManager.shared.currentDid {
            ProfileView(
              viewModel: ProfileViewModel(
                actor: did, profile: .init(did: "", handle: "", labels: [])))
          }
        }
        .onChange(of: viewModel.targetScrollUri) { _, uri in
          guard let uri else { return }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { scrollProxy?.scrollTo(uri, anchor: .top) }
          }
          viewModel.targetScrollUri = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .background {
            viewModel.saveReadPosition(uri: viewModel.currentReadUri)
          } else if newPhase == .active,
            let lastFetch = viewModel.lastFetchDate,
            Date().timeIntervalSince(lastFetch) > 300
          {
            Task { try? await viewModel.fetchTimeline() }
          }
        }
        .task(id: "\(autoRefreshEnabled)-\(autoRefreshIntervalSeconds)") {
          guard autoRefreshEnabled else { return }
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(autoRefreshIntervalSeconds))
            guard !Task.isCancelled, !viewModel.isFetchingTimeline else { continue }
            try? await viewModel.fetchTimeline()
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
        Color.clear.frame(height: 0).id("top")
        ForEach(Array(viewModel.validFeeds.enumerated()), id: \.element.id) { index, feedItem in
          let prevItem = index > 0 ? viewModel.validFeeds[index - 1] : nil
          let nextItem =
            index + 1 < viewModel.validFeeds.count ? viewModel.validFeeds[index + 1] : nil
          let connectsAbove = prevItem.map { areThreadConnected($0, feedItem) } ?? false
          let connectsBelow = nextItem.map { areThreadConnected(feedItem, $0) } ?? false
          feedRow(
            feedItem, connectsToCardAbove: connectsAbove, connectsToCardBelow: connectsBelow)
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
      if viewModel.isFetchingTimeline && !viewModel.validFeeds.isEmpty {
        ProgressView()
          .progressViewStyle(LinearProgressViewStyle())
          .tint(.accentColor)
      }
    }
  }

  @ViewBuilder
  private func feedRow(
    _ feedItem: FeedItem, connectsToCardAbove: Bool = false, connectsToCardBelow: Bool = false
  ) -> some View {
    if let post = feedItem.post {
      let cardVM = TimelineCardViewModel(
        post: post, reason: feedItem.reason, reply: feedItem.reply,
        connectsToCardAbove: connectsToCardAbove, connectsToCardBelow: connectsToCardBelow)
      let detailVM = PostDetailViewModel(post: post)
      NavigationLink(destination: PostDetailView(viewModel: detailVM)) {
        TimelineCardView(viewModel: cardVM)
      }
      .buttonStyle(.plain)
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

  private func areThreadConnected(_ a: FeedItem, _ b: FeedItem) -> Bool {
    guard a.reason == nil, b.reason == nil,
      let uriA = a.post?.uri,
      let parentUriB = b.reply?.parent?.uri
    else { return false }
    return uriA == parentUriB
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
          FeedTabButton(
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
      if feedSelectorStyle == "dropdown" && viewModel.feedTabs.count > 1 {
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

  @ToolbarContentBuilder
  private var trailingToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { isShowMyProfile = true }) {
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
      Button {
        viewModel.clearUnreadCount()
        withAnimation { scrollProxy?.scrollTo("top", anchor: .top) }
      } label: {
        SwiftUI.Label(
          title: { Text("Top") },
          icon: {
            Image(systemName: "arrow.up.to.line")
              .overlay(alignment: .topTrailing) {
                if viewModel.unreadCount > 0 {
                  Text(viewModel.unreadCount > 99 ? "99+" : "\(viewModel.unreadCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .offset(x: 10, y: -8)
                }
              }
          }
        )
      }
      Button("Refresh", systemImage: "arrow.clockwise") {
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

// MARK: - Feed tab button

private struct FeedTabButton: View {
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
  var vm = ContentViewModel()
  return ContentView(viewModel: vm, isLoggedIn: .constant(true))
}
