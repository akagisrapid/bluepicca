import Foundation


class TimelineScreenModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    
    
    func fetchTimeline() async throws -> Void{
        do{
            self.feeds = try await GetTimelineApi().getTimeline().feed
            print(self.feeds)
        }
    }
}
