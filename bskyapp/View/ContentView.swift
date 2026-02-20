import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject var viewModel: ContentViewModel
  @Binding var isLoggedIn: Bool
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var isShowSettings = false
  @State private var selectedPostForLikes: Post?

  var body: some View {
    NavigationStack {
      VStack {
        if viewModel.isFetchingTimeline {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(2.0)  // サイズを調整したい場合
            .padding()
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
                  TimelineCardView(
                    viewModel: timelineCardViewModel)
                }
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
          }.listStyle(.plain)
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
          ToolbarItem(placement: .title){
              Text("timelines")
          }
          ToolbarItem(placement: .navigationBarTrailing){
              Button(action: {
                  isShowSettings = true
              }) {
                  Image(systemName: "gearshape")
              }
              .buttonStyle(.plain)
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
      .sheet(isPresented: $isShowSettings) {
        SettingsView(isLoggedIn: $isLoggedIn)
      }
    }
  }
}
#Preview {
  var vm = ContentViewModel()
  return ContentView(viewModel: vm, isLoggedIn: .constant(true))
}
