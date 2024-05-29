import Foundation

class TimelineCardViewModel: ObservableObject{
    @Published var feed: FeedItem
    init(feed: FeedItem) {
        self.feed = feed
    }
}
