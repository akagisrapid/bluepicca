import SwiftData
import SwiftUI

struct FeedGeneratorTimelineView: View {
  @StateObject var viewModel: FeedGeneratorTimelineViewModel

  init(feedUri: String, feedName: String) {
    _viewModel = StateObject(
      wrappedValue: FeedGeneratorTimelineViewModel(feedUri: feedUri, feedName: feedName))
  }

  var body: some View {
    Group {
      if viewModel.validFeeds.isEmpty && viewModel.isFetching {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .scaleEffect(1.5)
      } else if let error = viewModel.fetchError {
        VStack(spacing: 12) {
          Text(error)
            .foregroundColor(.secondary)
          Button("再試行") {
            Task { await viewModel.fetchFeed() }
          }
        }
      } else {
        List {
          ForEach(viewModel.validFeeds) { feedItem in
            if let post = feedItem.post {
              let cardVM = TimelineCardViewModel(
                post: post, reason: feedItem.reason, reply: feedItem.reply)
              NavigationLink(
                destination: PostDetailView(viewModel: PostDetailViewModel(post: post))
              ) {
                TimelineCardView(viewModel: cardVM)
              }
              .buttonStyle(.plain)
              .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
              .onAppear {
                if feedItem.id == viewModel.validFeeds.last?.id {
                  Task { await viewModel.loadMore() }
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
        .refreshable {
          await viewModel.fetchFeed()
        }
      }
    }
    .navigationTitle(viewModel.feedName)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.fetchFeed()
    }
  }
}
