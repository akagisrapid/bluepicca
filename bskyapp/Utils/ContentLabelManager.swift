import Foundation

enum LabelPolicy: String, CaseIterable {
  case hide = "hide"
  case blur = "blur"
  case show = "show"

  var label: String {
    switch self {
    case .hide: return "非表示"
    case .blur: return "警告付き"
    case .show: return "表示"
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
    sexualPolicy = LabelPolicy(rawValue: ud.string(forKey: "labelPolicy_sexual") ?? "") ?? .blur
    nudityPolicy = LabelPolicy(rawValue: ud.string(forKey: "labelPolicy_nudity") ?? "") ?? .blur
    graphicPolicy = LabelPolicy(rawValue: ud.string(forKey: "labelPolicy_graphic") ?? "") ?? .blur
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
