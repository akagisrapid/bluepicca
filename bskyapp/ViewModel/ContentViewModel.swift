import Foundation

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
        // リフレッシュ時はキャッシュをクリア
        if refresh {
            TimelineCacheManager.shared.clearCache()
            cursor = nil
            hasMoreData = true
        }
        
        guard !isFetchingTimeline else { return }
        
        do{
            self.isFetchingTimeline = true
            let timelineResponse = try await GetTimelineApi().getTimeline(cursor: refresh ? nil : cursor)
            
            if refresh || cursor == nil {
                // 初回読み込みまたはリフレッシュ時は置き換え
                self.feeds = timelineResponse.feed
            } else {
                // 追加読み込み時は既存データに追加
                self.feeds.append(contentsOf: timelineResponse.feed)
            }
            
            // postフィールドがnilの場合は除外する
            self.posts = self.feeds.compactMap { $0.post }
            
            // 次のページのカーソルを保存
            self.cursor = timelineResponse.cursor
            self.hasMoreData = timelineResponse.cursor != nil
            
            self.isFetchingTimeline = false
        }
        catch{
            self.isFetchingTimeline = false
            print(error)
            throw error
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
