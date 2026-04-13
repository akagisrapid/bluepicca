import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @StateObject var viewModel: ContentViewModel
  @Binding var isLoggedIn: Bool
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var isShowSettings = false
  @State private var isShowBookmarks = false
  @State private var isShowSearch = false
  @State private var selectedPostForLikes: Post?
  @State private var scrollProxy: ScrollViewProxy? = nil
  @AppStorage("feedSelectorStyle") private var feedSelectorStyle: String = "dropdown"

  var body: some View {
    NavigationStack {
      mainContent
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
          }
          viewModel.targetScrollUri = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .background {
            viewModel.saveReadPosition(uri: viewModel.validFeeds.first?.post?.uri)
          }
        }
        .alert("エラー", isPresented: Binding(
          get: { viewModel.feedError != nil },
          set: { if !$0 { viewModel.feedError = nil } }
        )) {
          Button("OK") { viewModel.feedError = nil }
        } message: {
          Text(viewModel.feedError ?? "")
        }
    }
  }

  // MARK: - Main content

  @ViewBuilder
  private var mainContent: some View {
    ZStack {
      if viewModel.validFeeds.isEmpty && viewModel.isFetchingTimeline {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .scaleEffect(1.5)
      } else {
        ScrollViewReader { proxy in
          List {
            Color.clear.frame(height: 0).id("top")
            ForEach(viewModel.validFeeds) { feedItem in
              feedRow(feedItem)
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
          .modifier(FeedTabStripModifier(
            show: feedSelectorStyle == "tabs" && viewModel.feedTabs.count > 1,
            strip: feedTabStrip
          ))
        }
        if viewModel.isFetchingTimeline {
          VStack {
            ProgressView()
              .progressViewStyle(LinearProgressViewStyle())
              .tint(.accentColor)
            Spacer()
          }
        }
      }
    }
  }

  @ViewBuilder
  private func feedRow(_ feedItem: FeedItem) -> some View {
    if let post = feedItem.post {
      let cardVM = TimelineCardViewModel(post: post, reason: feedItem.reason, reply: feedItem.reply)
      let detailVM = PostDetailViewModel(post: post)
      ZStack {
        NavigationLink(destination: PostDetailView(viewModel: detailVM)) {
          EmptyView()
        }
        .opacity(0)
        TimelineCardView(viewModel: cardVM)
      }
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      .id(post.uri ?? feedItem.id)
      .onAppear {
        if feedItem.id == viewModel.validFeeds.last?.id {
          Task { await viewModel.loadMore() }
        }
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
        Picker(selection: Binding(
          get: { viewModel.selectedTab.id },
          set: { id in
            if let tab = viewModel.feedTabs.first(where: { $0.id == id }) {
              viewModel.selectTab(tab)
            }
          }
        ), label: Image(systemName: "list.bullet")) {
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
      HStack(spacing: 16) {
        Button(action: { isShowSearch = true }) {
          Image(systemName: "magnifyingglass")
        }
        .buttonStyle(.plain)
        Button(action: { isShowSettings = true }) {
          Image(systemName: "gearshape")
        }
        .buttonStyle(.plain)
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
      Button("Top", systemImage: "arrow.up.to.line") {
        withAnimation { scrollProxy?.scrollTo("top", anchor: .top) }
      }
      Button("Refresh", systemImage: "arrow.clockwise") {
        Task {
          do {
            try await viewModel.fetchTimeline()
          } catch {
            print("Error fetching timeline: \(error)")
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
