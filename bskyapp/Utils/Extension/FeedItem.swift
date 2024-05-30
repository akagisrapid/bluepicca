import Foundation

extension FeedItem{
    var timelineText: String{
        guard let text = self.post.record.text else {
            return "no record text!"
        }
        return text // nilでないとき
    }
    
    var authorText: String{
        return self.post.author.displayName
    }
}
