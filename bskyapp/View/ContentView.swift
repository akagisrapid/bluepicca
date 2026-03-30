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

  var body: some View {
    NavigationStack {
      ZStack {
        if viewModel.validFeeds.isEmpty && viewModel.isFetchingTimeline {
          // 初回ロード時のみ中央スピナー
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
        } else {
          List {
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
      .safeAreaInset(edge: .top, spacing: 0) {
        FeedTabBar(tabs: viewModel.feedTabs, selectedId: viewModel.selectedTab.id) { tab in
          viewModel.selectTab(tab)
        }
      }
      .toolbar {
          ToolbarItem(placement: .title){
              Text(viewModel.selectedTab.name)
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
    }
  }
}
// MARK: - フィードタブバー

private struct FeedTabBar: View {
  let tabs: [FeedTab]
  let selectedId: String
  let onSelect: (FeedTab) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 0) {
        ForEach(tabs) { tab in
          Button(action: { onSelect(tab) }) {
            VStack(spacing: 4) {
              Text(tab.name)
                .font(.subheadline)
                .fontWeight(tab.id == selectedId ? .semibold : .regular)
                .foregroundColor(tab.id == selectedId ? .primary : .secondary)
                .lineLimit(1)
              Rectangle()
                .fill(tab.id == selectedId ? Color.accentColor : Color.clear)
                .frame(height: 2)
            }
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
        }
      }
    }
    .background(.bar)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

#Preview {
  var vm = ContentViewModel()
  return ContentView(viewModel: vm, isLoggedIn: .constant(true))
}
