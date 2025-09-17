import Foundation

class ContentViewModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var posts: [Post] = []
    @Published var isFetchingTimeline: Bool = false;
    @Published var isShowPostCard: Bool = false;
    
    // postフィールドがnilでないFeedItemのみを返す
    var validFeeds: [FeedItem] {
        return feeds.filter { $0.post != nil }
    }
    
    init() {
        Task{
            try await fetchTimeline()
        }
    }
    func fetchTimeline() async throws -> Void{
        do{
            self.isFetchingTimeline = true
            self.feeds = try await GetTimelineApi().getTimeline().feed
            // postフィールドがnilの場合は除外する
            self.posts = self.feeds.compactMap { $0.post }
            self.isFetchingTimeline = false
        }
        catch{
            self.isFetchingTimeline = false
            print(error)
        }
    }
    
}
