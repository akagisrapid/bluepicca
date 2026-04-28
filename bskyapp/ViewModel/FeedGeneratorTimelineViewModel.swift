import Foundation

class FeedGeneratorTimelineViewModel: ObservableObject {
  let feedUri: String
  let feedName: String

  @Published var feeds: [FeedItem] = []
  @Published var isFetching: Bool = false
  @Published var isLoadingMore: Bool = false
  @Published var fetchError: String? = nil

  private var cursor: String?
  private var currentFetchTask: Task<Void, Never>?

  init(feedUri: String, feedName: String) {
    self.feedUri = feedUri
    self.feedName = feedName
  }

  var validFeeds: [FeedItem] {
    let muteWordManager = MuteWordManager.shared
    return feeds.filter { feedItem in
      guard let post = feedItem.post else { return false }
      let viewer = post.author?.viewer
      if viewer?.muted == true { return false }
      if viewer?.blocking != nil { return false }
      let text = post.record?.text ?? ""
      if muteWordManager.matches(text) { return false }
      return true
    }
  }

  @MainActor
  func fetchFeed() async {
    currentFetchTask?.cancel()
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      self.isFetching = true
      self.cursor = nil
      self.fetchError = nil
      do {
        let response = try await GetFeedApi().getFeed(uri: self.feedUri, cursor: nil)
        try Task.checkCancellation()
        self.feeds = response.feed
        self.cursor = response.cursor
        PostStateManager.shared.syncWithServerState(posts: self.feeds.compactMap { $0.post })
      } catch {
        if !(error is CancellationError) {
          self.fetchError = "フィードの読み込みに失敗しました"
          print("FeedGeneratorTimelineViewModel: fetchFeed error: \(error)")
        }
      }
      self.isFetching = false
    }
    currentFetchTask = task
    try? await task.value
  }

  @MainActor
  func loadMore() async {
    guard !isLoadingMore, let cursor else { return }
    isLoadingMore = true
    do {
      let response = try await GetFeedApi().getFeed(uri: feedUri, cursor: cursor)
      feeds.append(contentsOf: response.feed)
      self.cursor = response.cursor
      PostStateManager.shared.syncWithServerState(posts: feeds.compactMap { $0.post })
    } catch {
      print("FeedGeneratorTimelineViewModel: loadMore error: \(error)")
    }
    isLoadingMore = false
  }
}
