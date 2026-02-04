import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @StateObject var viewModel: ContentViewModel
  @State private var isShowReplies = false
  @State private var isShowLikes = false
  @State private var selectedPostForLikes: Post?

  var body: some View {
    NavigationStack {
      VStack {
        Text("timelines")
        if viewModel.isFetchingTimeline {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(2.0)  // サイズを調整したい場合
            .padding()
        } else {
          List(viewModel.validFeeds) { feedItem in
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
    }

    .toolbar {
      ToolbarItem(placement: .bottomBar) {
        HStack {
          Button("Post", systemImage: "square.and.pencil") {
            withAnimation(.easeInOut(duration: 0.3)) {
              viewModel.isShowPostCard.toggle()
            }
          }
          Button("Replies", systemImage: "bubble.left.and.bubble.right") {
            isShowReplies = true
          }
          Button("Likes", systemImage: "heart") {
            isShowLikes = true
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
    }
    .sheet(isPresented: $isShowReplies) {
      RepliesView(viewModel: RepliesViewModel())
    }
    .sheet(isPresented: $isShowLikes) {
      LikedPostsView(viewModel: LikedPostsViewModel())
    }
  }
}
#Preview {
  var vm = ContentViewModel()
  return ContentView(viewModel: vm)
}
