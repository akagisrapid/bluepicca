import Foundation

class TimelineCardScreenModel: ObservableObject{
    @Published var feed: FeedItem
    init(feed: FeedItem) {
        self.feed = feed
    }
}
