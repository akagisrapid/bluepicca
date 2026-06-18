import SwiftUI

class UserHighlightManager: ObservableObject {
  static let shared = UserHighlightManager()
  private let key = "userHighlightColors"

  @Published var highlights: [String: String] = [:]

  static let presetColors: [(label: String, hex: String)] = [
    ("赤", "#FF6B6B"),
    ("オレンジ", "#FF9E45"),
    ("黄", "#FFD93D"),
    ("緑", "#6BCB77"),
    ("青", "#4D96FF"),
    ("紫", "#C77DFF"),
  ]

  private init() {
    highlights = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
  }

  func set(did: String, hex: String) {
    highlights[did] = hex
    save()
  }

  func remove(did: String) {
    highlights.removeValue(forKey: did)
    save()
  }

  func color(for did: String) -> Color? {
    guard let hex = highlights[did] else { return nil }
    let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8) & 0xFF) / 255
    let b = Double(int & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
  }

  func hasHighlight(for did: String) -> Bool {
    highlights[did] != nil
  }

  private func save() {
    UserDefaults.standard.set(highlights, forKey: key)
  }
}
