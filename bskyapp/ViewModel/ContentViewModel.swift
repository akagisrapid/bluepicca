import Foundation

class ContentViewModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var posts: [Post] = []
    @Published var isFetchingTimeline: Bool = false;
    
    init() {
        Task{
            try await fetchTimeline()
        }
    }
    func fetchTimeline() async throws -> Void{
        do{
            self.isFetchingTimeline = true
            self.feeds = try await GetTimelineApi().getTimeline().feed
            self.posts = self.feeds.map { $0.post }
            self.isFetchingTimeline = false
        }
        catch{
            self.isFetchingTimeline = false
            print(error)
        }
    }
    
}
