import Foundation

class TimelineScreenModel: ObservableObject{
    var timeline: FeedResponse
    init(timeline: FeedResponse)  {
        self.timeline = timeline
    }
    
    
    func fetchTimeline() async throws -> Void{
        do{
            let timeline = try await getTimeline()
            self.timeline = timeline
        }
    }
}
