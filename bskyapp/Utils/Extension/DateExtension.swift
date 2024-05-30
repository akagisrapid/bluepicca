//
//  DateExtension.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation

extension Date {
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: self)
    }
    
    func removeMilliSecond() -> Date?{
        let iso8601StringWithMilliseconds = self.ISO8601Format()
        let formatter = ISO8601DateFormatter()
        // 正規表現でミリ秒部分を取り除く
        let pattern = "\\.\\d{3}Z"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: iso8601StringWithMilliseconds.utf16.count)
        let modifiedString = regex.stringByReplacingMatches(in: iso8601StringWithMilliseconds, options: [], range: range, withTemplate: "Z")
        
        return formatter.date(from: modifiedString)
    }
    
    var relativeDateString: String{
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        guard let date = formatter.string(for: self) else{
            return "invalid"
        }
        return date
    }
}
