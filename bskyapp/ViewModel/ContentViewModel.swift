import Foundation

class ContentViewModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var posts: [Post] = []
    @Published var isFetchingTimeline: Bool = false
    @Published var isShowPostCard: Bool = false
    
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
}
