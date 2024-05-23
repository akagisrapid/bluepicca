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
    
    var postTimeDate: Date? {
        let iso8601StringWithMilliseconds = self.post.record.createdAt ?? ""
        // 正規表現でミリ秒部分を取り除く
        let pattern = "\\.\\d{3}Z"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: iso8601StringWithMilliseconds.utf16.count)
        let modifiedString = regex.stringByReplacingMatches(in: iso8601StringWithMilliseconds, options: [], range: range, withTemplate: "Z")
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: modifiedString)
    }
    
    var postTimeDiffText: String{
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        guard let date = formatter.string(for: self.postTimeDate) else{
            return "invalid"
        }
        return date
    }

    
}
