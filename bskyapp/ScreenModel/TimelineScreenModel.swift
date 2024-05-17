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
    
    init(feeds: [FeedItem]){
        self.feeds = feeds
    }
    func fetchTimeline() async throws -> Void{
        do{
            self.feeds = try await GetTimelineApi().getTimeline().feed
        }
        catch{
            print(error)
        }
    }
}
