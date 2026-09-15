import Foundation

/// HTML の og:title / og:description / og:image メタタグを抽出する。
/// ponytail: 属性順序違い・引用符違いのみ対応。JS描画ページのOGPは取得できない。
enum OpenGraphParser {
  struct Metadata {
    let title: String?
    let description: String?
    let imageURL: String?
  }

  static func parse(html: String) -> Metadata {
    Metadata(
      title: content(forProperty: "og:title", in: html) ?? title(in: html),
      description: content(forProperty: "og:description", in: html),
      imageURL: content(forProperty: "og:image", in: html)
    )
  }

  private static func content(forProperty property: String, in html: String) -> String? {
    let patterns = [
      #"<meta[^>]+property=["']\#(property)["'][^>]+content=["']([^"']*)["']"#,
      #"<meta[^>]+content=["']([^"']*)["'][^>]+property=["']\#(property)["']"#,
    ]
    for pattern in patterns {
      if let value = firstMatch(pattern: pattern, in: html) {
        return value.htmlDecoded
      }
    }
    return nil
  }

  private static func title(in html: String) -> String? {
    firstMatch(pattern: #"<title[^>]*>([^<]*)</title>"#, in: html)?.htmlDecoded
  }

  private static func firstMatch(pattern: String, in html: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    let range = NSRange(html.startIndex..., in: html)
    guard let match = regex.firstMatch(in: html, range: range),
      let group = Range(match.range(at: 1), in: html)
    else { return nil }
    return String(html[group])
  }
}

extension String {
  /// OGPのcontent属性に現れる代表的なHTML実体参照のみをデコードする。
  /// ponytail: NSAttributedStringのHTML初期化子はWebKit経由でメインスレッド専用のため使わない。
  fileprivate var htmlDecoded: String {
    let namedEntities: [String: String] = [
      "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
    ]
    var result = self
    for (entity, replacement) in namedEntities {
      result = result.replacingOccurrences(of: entity, with: replacement)
    }
    return result
  }
}
