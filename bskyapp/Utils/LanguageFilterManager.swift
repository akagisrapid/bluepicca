import Foundation

/// TL に表示する言語。何も選んでいないときは絞らない
class LanguageFilterManager: ObservableObject {
  static let shared = LanguageFilterManager()
  private let key = "languageFilterAllowed"

  /// 設定画面で選べる言語（BCP 47 の主言語タグ）
  static let candidates = ["ja", "en", "ko", "zh", "es", "pt", "fr", "de", "it", "ru", "id", "th"]

  @Published var allowedLanguages: Set<String> {
    didSet { UserDefaults.standard.set(Array(allowedLanguages), forKey: key) }
  }

  private init() {
    allowedLanguages = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
  }

  var isActive: Bool { !allowedLanguages.isEmpty }

  func toggle(_ code: String) {
    if allowedLanguages.contains(code) {
      allowedLanguages.remove(code)
    } else {
      allowedLanguages.insert(code)
    }
  }

  func allows(_ langs: [String]?) -> Bool {
    Self.allows(langs, allowed: allowedLanguages)
  }

  /// 投稿の `langs` のどれかが選んだ言語なら表示する。
  /// 言語の付いていない投稿は判定できないので表示する
  static func allows(_ langs: [String]?, allowed: Set<String>) -> Bool {
    guard !allowed.isEmpty, let langs, !langs.isEmpty else { return true }
    return langs.contains { allowed.contains(primaryTag($0)) }
  }

  /// "en-US" → "en"、"zh_Hant" → "zh"
  static func primaryTag(_ lang: String) -> String {
    let tag = lang.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? ""
    return tag.lowercased()
  }

  static func displayName(_ code: String) -> String {
    Locale.current.localizedString(forLanguageCode: code) ?? code
  }

  /// 設定画面の行に出す要約（"日本語、英語" など）。絞っていないときは nil
  var summary: String? {
    guard isActive else { return nil }
    let names = Self.candidates.filter { allowedLanguages.contains($0) }.map(Self.displayName)
    return ListFormatter.localizedString(byJoining: names)
  }
}
