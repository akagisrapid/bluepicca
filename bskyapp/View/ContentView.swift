import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject var viewModel: ContentViewModel
  @Binding var isLoggedIn: Bool
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var isShowSettings = false
  @State private var isShowBookmarks = false
  @State private var isShowSearch = false
  @State private var selectedPostForLikes: Post?
  @State private var scrollProxy: ScrollViewProxy? = nil

  var body: some View {
    NavigationStack {
      ZStack {
        if viewModel.validFeeds.isEmpty && viewModel.isFetchingTimeline {
          // 初回ロード時のみ中央スピナー
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
        } else {
          ScrollViewReader { proxy in
            List {
              Color.clear.frame(height: 0).id("top")
              ForEach(viewModel.validFeeds) { feedItem in
                if let post = feedItem.post {
                  var timelineCardViewModel = TimelineCardViewModel(
                    post: post, reason: feedItem.reason, reply: feedItem.reply)
                  var postDetailViewModel = PostDetailViewModel(post: post)
                  ZStack {
                    NavigationLink(
                      destination: PostDetailView(viewModel: postDetailViewModel)
                    ) {
                      EmptyView()
                    }
                    .opacity(0)
                    TimelineCardView(viewModel: timelineCardViewModel)
                  }
                  .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                  .onAppear {
                    if feedItem.id == viewModel.validFeeds.last?.id {
                      Task {
                        await viewModel.loadMore()
                      }
                    }
                  }
                }
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
          }
          // リフレッシュ中は上部に細いインジケーターを表示
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

      .sheet(isPresented: $viewModel.isShowPostCard) {
        ZStack {
          PostCardView(
            viewModel: PostCardViewModel(text: ""), isShowPostCard: $viewModel.isShowPostCard
          )
          .padding()
          .background(.clear)  // PostCardViewの背景色
          .cornerRadius(10)
          .shadow(radius: 5)
          .padding()
          .transition(.scale)
        }
      }
      .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
              if viewModel.feedTabs.count > 1 {
                  Picker(selection: Binding(
                      get: { viewModel.selectedTab.id },
                      set: { id in
                          if let tab = viewModel.feedTabs.first(where: { $0.id == id }) {
                              viewModel.selectTab(tab)
                          }
                      }
                  ), label: Text(viewModel.selectedTab.name).fontWeight(.semibold)) {
                      ForEach(viewModel.feedTabs) { tab in
                          Text(tab.name).tag(tab.id)
                      }
                  }
                  .pickerStyle(.menu)
              } else {
                  Text(viewModel.selectedTab.name).fontWeight(.semibold)
              }
          }
          ToolbarItem(placement: .navigationBarTrailing){
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
              withAnimation {
                scrollProxy?.scrollTo("top", anchor: .top)
              }
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
      .sheet(isPresented: $isShowReplies) {
        RepliesView(viewModel: RepliesViewModel())
      }
      .sheet(isPresented: $isShowBookmarks) {
        BookmarksView()
      }
      .sheet(isPresented: $isShowSettings) {
        SettingsView(isLoggedIn: $isLoggedIn)
      }
      .sheet(isPresented: $isShowSearch) {
        SearchView()
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
}

#Preview {
  var vm = ContentViewModel()
  return ContentView(viewModel: vm, isLoggedIn: .constant(true))
}
