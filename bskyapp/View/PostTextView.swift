import SwiftUI

struct PostTextView: View {
    let text: String
    let onHashtagTap: (String) -> Void

    var body: some View {
        Text(buildAttributedString())
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "bluepicca",
                      url.host == "hashtag",
                      let encoded = url.pathComponents.last,
                      let tag = encoded.removingPercentEncoding
                else { return .systemAction }
                onHashtagTap("#\(tag)")
                return .handled
            })
    }

    private func buildAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        guard let pattern = try? NSRegularExpression(pattern: "#[^\\s#.,!?;:'\"()\\[\\]{}]+") else {
            return attributed
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, range: range)
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: text),
                  let attrRange = Range(swiftRange, in: attributed) else { continue }
            let tag = String(text[swiftRange].dropFirst())
            let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
            attributed[attrRange].foregroundColor = .accentColor
            attributed[attrRange].link = URL(string: "bluepicca://hashtag/\(encoded)")
        }
        return attributed
    }
}
