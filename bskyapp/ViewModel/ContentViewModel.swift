import Foundation

struct TimeoutError: Error {}

class ContentViewModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var posts: [Post] = []
    @Published var isFetchingTimeline: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var isShowPostCard: Bool = false
    
    private var cursor: String?
    private var hasMoreData: Bool = true
    
    // postフィールドがnilでないFeedItemのみを返す
    var validFeeds: [FeedItem] {
        return feeds.filter { $0.post != nil }
    }
    
    init() {
        Task { @MainActor in
            try await fetchTimeline()
        }
    }
    
    @MainActor
    func fetchTimeline(refresh: Bool = false) async throws -> Void{
        print("ContentViewModel: fetchTimeline called with refresh: \(refresh)")
        print("ContentViewModel: Current state - isFetchingTimeline: \(isFetchingTimeline)")
        
        // リフレッシュ時はキャッシュをクリア
        if refresh {
            print("ContentViewModel: Clearing cache and resetting state")
            TimelineCacheManager.shared.clearCache()
            cursor = nil
            hasMoreData = true
            // リフレッシュ時は強制的にフラグをリセット
            self.isFetchingTimeline = false
        }
        
        // フラグがtrueの場合、強制的にリセットして続行
        if isFetchingTimeline {
            print("ContentViewModel: Force resetting isFetchingTimeline flag")
            self.isFetchingTimeline = false
        }
        
        print("ContentViewModel: Starting timeline fetch")
        self.isFetchingTimeline = true
        
        do{
            print("ContentViewModel: Calling GetTimelineApi with cursor: \(cursor ?? "nil")")
            
            // タイムアウト付きでAPI呼び出し
            let timelineResponse = try await withTimeout(seconds: 15) {
                try await GetTimelineApi().getTimeline(cursor: refresh ? nil : self.cursor)
            }
            
            print("ContentViewModel: Received timeline response with \(timelineResponse.feed.count) items")
            
            if refresh || cursor == nil {
                // 初回読み込みまたはリフレッシュ時は置き換え
                print("ContentViewModel: Replacing feeds (refresh or initial load)")
                self.feeds = timelineResponse.feed
            } else {
                // 追加読み込み時は既存データに追加
                print("ContentViewModel: Appending to existing feeds")
                self.feeds.append(contentsOf: timelineResponse.feed)
            }
            
            // postフィールドがnilの場合は除外する
            self.posts = self.feeds.compactMap { $0.post }
            print("ContentViewModel: Updated posts count: \(self.posts.count)")
            
            // 次のページのカーソルを保存
            self.cursor = timelineResponse.cursor
            self.hasMoreData = timelineResponse.cursor != nil
            print("ContentViewModel: Updated cursor: \(self.cursor ?? "nil"), hasMoreData: \(self.hasMoreData)")
            
            self.isFetchingTimeline = false
            print("ContentViewModel: Timeline fetch completed successfully")
        }
        catch{
            self.isFetchingTimeline = false
            print("ContentViewModel: Timeline fetch error: \(error)")
            throw error
        }
    }
    
    // タイムアウト付きでタスクを実行するヘルパー関数
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 実際の処理
            group.addTask {
                try await operation()
            }
            
            // タイムアウト処理
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // 最初に完了したタスクの結果を返す
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    @MainActor
    func loadMoreTimeline() async {
        guard !isLoadingMore && hasMoreData && cursor != nil else { return }
        
        do {
            self.isLoadingMore = true
            let timelineResponse = try await GetTimelineApi().getTimeline(cursor: cursor)
            
            // 既存データに追加
            self.feeds.append(contentsOf: timelineResponse.feed)
            self.posts = self.feeds.compactMap { $0.post }
            
            // 次のページのカーソルを更新
            self.cursor = timelineResponse.cursor
            self.hasMoreData = timelineResponse.cursor != nil
            
            self.isLoadingMore = false
        } catch {
            self.isLoadingMore = false
            print("Failed to load more timeline: \(error)")
        }
    }
    
    @MainActor
    func refreshTimeline() async {
        do {
            try await fetchTimeline(refresh: true)
        } catch {
            print("Failed to refresh timeline: \(error)")
        }
    }
}

