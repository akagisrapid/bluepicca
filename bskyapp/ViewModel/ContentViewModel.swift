import Foundation

class ContentViewModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var posts: [Post] = []
    @Published var isFetchingTimeline: Bool = false
    @Published var isShowPostCard: Bool = false
    @Published var isLoadingMore: Bool = false
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
            try await fetchTimeline()
        }
    }
    
    @MainActor
    func fetchTimeline() async throws -> Void{
        print("ContentViewModel: fetchTimeline called")
        
        
        print("ContentViewModel: Starting timeline fetch")
        self.isFetchingTimeline = true
        
        do{
            print("ContentViewModel: Calling GetTimelineApi")
            
            let timelineResponse = try await GetTimelineApi().getTimeline()

            print("ContentViewModel: Received timeline response with \(timelineResponse.feed.count) items")

            self.feeds = timelineResponse.feed
            self.posts = self.feeds.compactMap { $0.post }
            self.timelineCursor = timelineResponse.cursor

            // サーバーの状態でローカルのいいね/リポスト状態を同期
            PostStateManager.shared.syncWithServerState(posts: self.posts)

            print("ContentViewModel: Updated posts count: \(self.posts.count)")
            
            self.isFetchingTimeline = false
            print("ContentViewModel: Timeline fetch completed successfully")
        }
        catch{
            self.isFetchingTimeline = false
            print("ContentViewModel: Timeline fetch error: \(error)")
            throw error
        }
    }

    @MainActor
    func loadMore() async {
        guard !isLoadingMore, let cursor = timelineCursor else { return }
        isLoadingMore = true
        do {
            let response = try await GetTimelineApi().getTimeline(cursor: cursor)
            print("ContentViewModel: loadMore received \(response.feed.count) items")
            self.feeds.append(contentsOf: response.feed)
            self.posts = self.feeds.compactMap { $0.post }
            self.timelineCursor = response.cursor
            PostStateManager.shared.syncWithServerState(posts: self.posts)
        } catch {
            print("ContentViewModel: loadMore error: \(error)")
        }
        isLoadingMore = false
    }
}
