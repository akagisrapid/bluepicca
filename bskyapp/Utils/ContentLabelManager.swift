import Foundation

enum LabelPolicy: String, CaseIterable {
  case hide = "hide"
  case blur = "blur"
  case show = "show"

  var label: String {
    switch self {
    case .hide: return String(localized: "非表示")
    case .blur: return String(localized: "警告付き")
    case .show: return String(localized: "表示")
    }
  }
}

class ContentLabelManager: ObservableObject {
  static let shared = ContentLabelManager()

  private static let sexualLabels: Set<String> = ["porn", "sexual", "nsfw"]
  private static let nudityLabels: Set<String> = ["nudity"]
  private static let graphicLabels: Set<String> = ["graphic-media"]

  @Published var sexualPolicy: LabelPolicy {
    didSet { UserDefaults.standard.set(sexualPolicy.rawValue, forKey: "labelPolicy_sexual") }
  }
  @Published var nudityPolicy: LabelPolicy {
    didSet { UserDefaults.standard.set(nudityPolicy.rawValue, forKey: "labelPolicy_nudity") }
  }
  @Published var graphicPolicy: LabelPolicy {
    didSet { UserDefaults.standard.set(graphicPolicy.rawValue, forKey: "labelPolicy_graphic") }
  }

  private init() {
    let ud = UserDefaults.standard
    sexualPolicy = Self.loadPolicy(ud, key: "labelPolicy_sexual")
    nudityPolicy = Self.loadPolicy(ud, key: "labelPolicy_nudity")
    graphicPolicy = Self.loadPolicy(ud, key: "labelPolicy_graphic")
  }

  /// センシティブコンテンツを常時表示できてしまう `.show` はユーザー設定として選ばせない（App Store審査ガイドライン1.2対応）。
  /// 過去に `.show` を選んでいた端末は `.blur` へ移行する。
  private static func loadPolicy(_ ud: UserDefaults, key: String) -> LabelPolicy {
    let policy = LabelPolicy(rawValue: ud.string(forKey: key) ?? "") ?? .blur
    return policy == .show ? .blur : policy
  }

  func policy(for post: Post) -> LabelPolicy {
    guard let labels = post.labels, !labels.isEmpty else { return .show }
    var result: LabelPolicy = .show
    for label in labels where label.neg != true {
      let val = label.val
      let p: LabelPolicy
      if Self.sexualLabels.contains(val) {
        p = sexualPolicy
      } else if Self.nudityLabels.contains(val) {
        p = nudityPolicy
      } else if Self.graphicLabels.contains(val) {
        p = graphicPolicy
      } else {
        continue
      }
      if p == .hide { return .hide }
      if p == .blur { result = .blur }
    }
    return result
  }
}
