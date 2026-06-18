import Alamofire
import Combine
import Foundation

extension Notification.Name {
  static let postCreated = Notification.Name("postCreated")
}

class ContentViewModel: ObservableObject {
  @Published var feeds: [FeedItem] = []
  @Published var posts: [Post] = []
  @Published var isFetchingTimeline: Bool = false
  @Published var isShowPostCard: Bool = false
  @Published var isLoadingMore: Bool = false

  @Published var feedTabs: [FeedTab] = [.home]
  @Published var selectedTab: FeedTab = .home
  @Published var isLoadingFeedTabs: Bool = false
  @Published var feedError: String? = nil

  /// フィードロード後にスクロールすべき投稿URI（一度使ったらnilにする）
  @Published var targetScrollUri: String? = nil
  /// 既読位置より上の新着投稿数（Topボタンのバッジ）
  @Published var unreadCount: Int = 0
  /// 現在画面上に表示されている先頭付近のセルURI（表示中セルの最小インデックス）
  var currentReadUri: String? = nil
  private var visiblePostUris: Set<String> = []

  private func lastReadUriKey(for tabId: String) -> String {
    "lastReadPostUri_\(tabId)"
  }

  private var currentFetchTask: Task<Void, any Error>?
  private var postCreatedObserver: NSObjectProtocol?
  private var hashtagFeedCancellable: AnyCancellable?
  var lastFetchDate: Date?

  var timelineCursor: String?

  private struct FeedCache {
    var feeds: [FeedItem]
    var cursor: String?
  }
  private var feedsCache: [String: FeedCache] = [:]

  // ミュート・ブロック済みアカウント・ミュートワード・RTフィルタ・ラベルポリシーに該当する投稿を除外する
  var validFeeds: [FeedItem] {
    let muteWordManager = MuteWordManager.shared
    let rtFilterManager = RTFilterManager.shared
    let labelManager = ContentLabelManager.shared
    return feeds.filter { feedItem in
      guard let post = feedItem.post else { return false }
      let viewer = post.author?.viewer
      if viewer?.muted == true { return false }
      if viewer?.blocking != nil { return false }
      let text = post.record?.text ?? ""
      if muteWordManager.matches(text) { return false }
      if let repostDid = feedItem.reason?.by?.did,
        rtFilterManager.isFiltered(repostDid)
      {
        return false
      }
      if labelManager.policy(for: post) == .hide { return false }
      return true
    }
  }

  init() {
    Task { @MainActor [weak self] in
      await self?.loadFeedTabs()
      try await self?.fetchTimeline()
    }
    postCreatedObserver = NotificationCenter.default.addObserver(
      forName: .postCreated, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        try? await self?.fetchTimeline()
      }
    }
    hashtagFeedCancellable = HashtagFeedManager.shared.$hashtags
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] hashtags in
        guard let self else { return }
        Task { @MainActor [weak self] in
          guard let self else { return }
          let nonHashtagTabs = self.feedTabs.filter { $0.hashtag == nil }
          self.feedTabs = nonHashtagTabs + hashtags.map { FeedTab.forHashtag($0) }
          if let removed = self.selectedTab.hashtag, !hashtags.contains(removed) {
            self.selectTab(.home)
          }
        }
      }
  }

  deinit {
    if let observer = postCreatedObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: - フィードタブ読み込み

  @MainActor
  func loadFeedTabs() async {
    isLoadingFeedTabs = true
    do {
      var tabs = try await GetUserFeedsApi().getUserFeeds()
      tabs += HashtagFeedManager.shared.feedTabs
      feedTabs = tabs
    } catch {
      dlog("ContentViewModel: loadFeedTabs error: \(error)")
      feedTabs = [.home] + HashtagFeedManager.shared.feedTabs
    }
    isLoadingFeedTabs = false
  }

  // MARK: - タイムライン取得

  @MainActor
  func fetchTimeline() async throws {
    // 前回の取得が進行中なら中断して新しいリクエストを優先する
    currentFetchTask?.cancel()

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      dlog("ContentViewModel: fetchTimeline called (tab: \(self.selectedTab.name))")
      self.isFetchingTimeline = true
      self.timelineCursor = nil

      do {
        let response = try await self.fetchFeed(cursor: nil)
        try Task.checkCancellation()
        self.feeds = response.feed
        self.posts = self.feeds.compactMap { $0.post }
        self.timelineCursor = response.cursor
        self.feedsCache[self.selectedTab.id] = FeedCache(
          feeds: self.feeds, cursor: self.timelineCursor)
        self.lastFetchDate = Date()
        PostStateManager.shared.syncWithServerState(posts: self.posts)
        self.isFetchingTimeline = false

        // 既読位置が保存されていればスクロールターゲットとしてセット
        self.unreadCount = 0
        let key = self.lastReadUriKey(for: self.selectedTab.id)
        let savedUri = UserDefaults.standard.string(forKey: key)
        if let uri = savedUri,
          let index = self.feeds.firstIndex(where: { $0.post?.uri == uri })
        {
          self.targetScrollUri = uri
          self.unreadCount = index
          UserDefaults.standard.removeObject(forKey: key)
        }
      } catch {
        self.isFetchingTimeline = false
        if !(error is CancellationError) {
          dlog("ContentViewModel: fetchTimeline error: \(error)")
        }
        throw error
      }
    }
    currentFetchTask = task
    try await task.value
  }

  // MARK: - 既読位置の保存

  func saveReadPosition(uri: String?) {
    UserDefaults.standard.set(uri, forKey: lastReadUriKey(for: selectedTab.id))
  }

  @MainActor
  func cellDidAppear(uri: String) {
    visiblePostUris.insert(uri)
    refreshCurrentReadUri()
  }

  @MainActor
  func cellDidDisappear(uri: String) {
    visiblePostUris.remove(uri)
    refreshCurrentReadUri()
  }

  private func refreshCurrentReadUri() {
    currentReadUri = validFeeds.compactMap { $0.post?.uri }.first { visiblePostUris.contains($0) }
  }

  @MainActor
  func clearUnreadCount() {
    unreadCount = 0
  }

  @MainActor
  func loadMore() async {
    guard !isLoadingMore, let cursor = timelineCursor else { return }
    isLoadingMore = true
    do {
      let response = try await fetchFeed(cursor: cursor)
      feeds.append(contentsOf: response.feed)
      posts = feeds.compactMap { $0.post }
      timelineCursor = response.cursor
      feedsCache[selectedTab.id] = FeedCache(feeds: feeds, cursor: timelineCursor)
      PostStateManager.shared.syncWithServerState(posts: posts)
    } catch {
      dlog("ContentViewModel: loadMore error: \(error)")
    }
    isLoadingMore = false
  }

  // MARK: - タブ切り替え

  @MainActor
  func selectTab(_ tab: FeedTab) {
    guard tab.id != selectedTab.id else { return }
    saveReadPosition(uri: currentReadUri)
    currentFetchTask?.cancel()
    currentReadUri = nil
    visiblePostUris = []
    selectedTab = tab
    feedError = nil

    if let cached = feedsCache[tab.id] {
      feeds = cached.feeds
      timelineCursor = cached.cursor
      unreadCount = 0
      let restoreScroll =
        UserDefaults.standard.object(forKey: "restoreScrollOnTabSwitch") as? Bool ?? true
      let key = lastReadUriKey(for: tab.id)
      if restoreScroll,
        let savedUri = UserDefaults.standard.string(forKey: key),
        feeds.contains(where: { $0.post?.uri == savedUri })
      {
        targetScrollUri = savedUri
        UserDefaults.standard.removeObject(forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    } else {
      feeds = []
      currentFetchTask = Task {
        do {
          try await fetchTimeline()
        } catch is CancellationError {
          // タブ切り替えによるキャンセルは無視
        } catch {
          feedError =
            (error as? AFError)?.responseCode == 429
            ? error.userFacingMessage
            : "フィードの読み込みに失敗しました: \(error.localizedDescription)"
          dlog("ContentViewModel: selectTab fetchTimeline error: \(error)")
        }
      }
    }
  }

  // MARK: - 内部: タブに応じて適切なAPIを呼ぶ

  @MainActor
  private func fetchFeed(cursor: String?) async throws -> FeedResponse {
    if let hashtag = selectedTab.hashtag {
      let response = try await SearchPostsApi().searchPosts(query: hashtag, cursor: cursor)
      let feedItems = response.posts.map { FeedItem(post: $0) }
      return FeedResponse(cursor: response.cursor, feed: feedItems)
    } else if let uri = selectedTab.uri {
      return try await GetFeedApi().getFeed(uri: uri, cursor: cursor)
    } else {
      return try await GetTimelineApi().getTimeline(cursor: cursor)
    }
  }

  // MARK: - ハッシュタグフィード管理

  @MainActor
  func addHashtagFeed(_ tag: String) {
    HashtagFeedManager.shared.add(tag)
    guard !feedTabs.contains(where: { $0.hashtag == tag }) else { return }
    feedTabs.append(FeedTab.forHashtag(tag))
  }

  @MainActor
  func removeHashtagFeed(_ tag: String) {
    HashtagFeedManager.shared.remove(tag)
    feedTabs.removeAll { $0.hashtag == tag }
    if selectedTab.hashtag == tag {
      selectTab(.home)
    }
  }
}
