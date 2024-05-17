import Foundation


extension FeedItem{
    var timelineText: String{
        guard let text = self.post.record.text else {
            return "no record text!"
        }
        return text // nilでないとき
    }
}
class TimelineScreenModel: ObservableObject{
    @Published var feeds: [FeedItem] = []
    @Published var isFetchingTimeline: Bool = false;
    init(feeds: [FeedItem]){
        self.feeds = feeds
    }
    func fetchTimeline() async throws -> Void{
        do{
            self.isFetchingTimeline = true
            self.feeds = try await GetTimelineApi().getTimeline().feed
            self.isFetchingTimeline = false
        }
        catch{
            self.isFetchingTimeline = false
            print(error)
        }
    }
}
