import Foundation

extension String{
    var parseToDateRemovingMilliseconds: Date? {
        let iso8601StringWithMilliseconds = self
        // 正規表現でミリ秒部分を取り除く
        let pattern = "\\.\\d{3}Z"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: iso8601StringWithMilliseconds.utf16.count)
        let modifiedString = regex.stringByReplacingMatches(in: iso8601StringWithMilliseconds, options: [], range: range, withTemplate: "Z")
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: modifiedString)
    }
}
