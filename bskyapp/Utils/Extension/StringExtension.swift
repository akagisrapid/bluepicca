import Foundation
import SwiftUI
import UIKit

extension String{
    // APIで取得したString型の日付を、ms部分を取り除いてパース
    var parseToDateRemovingMilliseconds: Date? {
        let iso8601StringWithMilliseconds = self
        // 正規表現でミリ秒部分を取り除く
        let pattern = "\\.\\d{3}Z"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // 正規表現の作成に失敗した場合は、元の文字列をそのままパースしてみる
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: iso8601StringWithMilliseconds)
        }
        
        let range = NSRange(location: 0, length: iso8601StringWithMilliseconds.utf16.count)
        let modifiedString = regex.stringByReplacingMatches(in: iso8601StringWithMilliseconds, options: [], range: range, withTemplate: "Z")
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: modifiedString)
    }
    
    // テキスト内のURLを検出してAttributedStringに変換する
    func detectLinks() -> AttributedString {
        // NSAttributedStringを使用して実装
        let attributedString = NSMutableAttributedString(string: self)
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(attributedString)
        }
        
        let matches = detector.matches(in: self, range: NSRange(location: 0, length: self.count))
        
        for match in matches {
            if let url = match.url {
                attributedString.addAttribute(.link, value: url, range: match.range)
                attributedString.addAttribute(.foregroundColor, value: UIColor(Color.blue), range: match.range)
            }
        }
        
        return AttributedString(attributedString)
    }
}
