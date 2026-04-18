import Foundation
import Alamofire

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

    private let lastReadUriKey = "lastReadPostUri"
    private var currentFetchTask: Task<Void, any Error>?
    private var postCreatedObserver: NSObjectProtocol?

    var timelineCursor: String?

    // ミュート・ブロック済みアカウント・ミュートワードに該当する投稿を除外する
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

    init() {
        Task { @MainActor in
            await loadFeedTabs()
            try await fetchTimeline()
        }
        postCreatedObserver = NotificationCenter.default.addObserver(forName: .postCreated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.fetchTimeline()
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
            feedTabs = try await GetUserFeedsApi().getUserFeeds()
        } catch {
            print("ContentViewModel: loadFeedTabs error: \(error)")
            feedTabs = [.home]
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
            print("ContentViewModel: fetchTimeline called (tab: \(self.selectedTab.name))")
            self.isFetchingTimeline = true
            self.timelineCursor = nil

            do {
                let response = try await self.fetchFeed(cursor: nil)
                try Task.checkCancellation()
                self.feeds = response.feed
                self.posts = self.feeds.compactMap { $0.post }
                self.timelineCursor = response.cursor
                PostStateManager.shared.syncWithServerState(posts: self.posts)
                self.isFetchingTimeline = false

                // 既読位置が保存されていればスクロールターゲットとしてセット
                let savedUri = UserDefaults.standard.string(forKey: self.lastReadUriKey)
                if let uri = savedUri, self.feeds.contains(where: { $0.post?.uri == uri }) {
                    self.targetScrollUri = uri
                    UserDefaults.standard.removeObject(forKey: self.lastReadUriKey)
                }
            } catch {
                self.isFetchingTimeline = false
                if !(error is CancellationError) {
                    print("ContentViewModel: fetchTimeline error: \(error)")
                }
                throw error
            }
        }
        currentFetchTask = task
        try await task.value
    }

    // MARK: - 既読位置の保存

    func saveReadPosition(uri: String?) {
        UserDefaults.standard.set(uri, forKey: lastReadUriKey)
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
            PostStateManager.shared.syncWithServerState(posts: posts)
        } catch {
            print("ContentViewModel: loadMore error: \(error)")
        }
        isLoadingMore = false
    }

    // MARK: - タブ切り替え

    @MainActor
    func selectTab(_ tab: FeedTab) {
        guard tab.id != selectedTab.id else { return }
        currentFetchTask?.cancel()
        selectedTab = tab
        feedError = nil
        currentFetchTask = Task {
            do {
                try await fetchTimeline()
            } catch is CancellationError {
                // タブ切り替えによるキャンセルは無視
            } catch {
                feedError = (error as? AFError)?.responseCode == 429
                    ? error.userFacingMessage
                    : "フィードの読み込みに失敗しました: \(error.localizedDescription)"
                print("ContentViewModel: selectTab fetchTimeline error: \(error)")
            }
        }
    }

    // MARK: - 内部: タブに応じて適切なAPIを呼ぶ

    @MainActor
    private func fetchFeed(cursor: String?) async throws -> FeedResponse {
        if let uri = selectedTab.uri {
            return try await GetFeedApi().getFeed(uri: uri, cursor: cursor)
        } else {
            return try await GetTimelineApi().getTimeline(cursor: cursor)
        }
    }
}
