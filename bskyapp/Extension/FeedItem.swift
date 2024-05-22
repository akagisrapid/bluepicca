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
    var postTimeDiffText: String{
        let dateString = self.post.record.createdAt ?? ""
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.doesRelativeDateFormatting = true
        
        guard let d = formatter.date(from: dateString) else{
            return "invalid date"
        }
        return formatter.string(from: d)
        
       
        let calendar = Calendar.current
        guard let fromDate = formatter.date(from: dateString)
        else {
            return "inva"
        }
            
            // 時間の差を計算
        let components = calendar.dateComponents([.minute, .hour, .day, .month], from: fromDate, to: Date())
            
            if let minutes = components.minute, let hours = components.hour, let days = components.day {
                // 1時間以内の場合
                if hours == 0 && days == 0 {
                    return "\(minutes)分前"
                }
                
                // 1日以内の場合
                if days == 0 {
                    return "\(hours)時間前"
                }
                
                // 1ヶ月以内の場合
                return "\(days)日前"
            }
            
            return fromDate.ISO8601Format()
        }

    
}
