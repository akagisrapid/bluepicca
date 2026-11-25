import SwiftUI
import UIKit

/// UITextViewベースの本文表示。長押しでのテキスト選択・コピーに対応しつつ、
/// ハッシュタグのタップ遷移も維持する（SwiftUIのText.textSelectionはリンク付き
/// AttributedStringと組み合わせると文字単位の選択ができないための代替）。
struct SelectablePostTextView: UIViewRepresentable {
  let text: String
  var font: UIFont = .preferredFont(forTextStyle: .title3)
  let onHashtagTap: (String) -> Void

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.delegate = context.coordinator
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    uiView.attributedText = buildAttributedString()
  }

  /// 提案された幅で折り返したときの高さを返す。幅が変わるたびに呼ばれるので、画面幅を推測しない。
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    // 幅の指定がない・無限大のときは今の幅で折り返す（1行のまま横に伸ばさない）
    let proposed = proposal.width.flatMap { $0.isFinite ? $0 : nil }
    let width = proposed ?? uiView.bounds.width
    guard width > 0 else { return nil }
    let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: size.height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onHashtagTap: onHashtagTap)
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    let onHashtagTap: (String) -> Void
    init(onHashtagTap: @escaping (String) -> Void) {
      self.onHashtagTap = onHashtagTap
    }

    func textView(
      _ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange,
      interaction: UITextItemInteraction
    ) -> Bool {
      guard URL.scheme == "bluepicca",
        URL.host == "hashtag",
        let encoded = URL.pathComponents.last,
        let tag = encoded.removingPercentEncoding
      else { return false }
      onHashtagTap("#\(tag)")
      return false
    }
  }

  private func buildAttributedString() -> NSAttributedString {
    let attributed = NSMutableAttributedString(
      string: text,
      attributes: [.font: font, .foregroundColor: UIColor.label]
    )
    guard let pattern = try? NSRegularExpression(pattern: "#[^\\s#.,!?;:'\"()\\[\\]{}]+") else {
      return attributed
    }
    let nsText = text as NSString
    let range = NSRange(location: 0, length: nsText.length)
    for match in pattern.matches(in: text, range: range) {
      let tag = String(nsText.substring(with: match.range).dropFirst())
      let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
      guard let url = URL(string: "bluepicca://hashtag/\(encoded)") else { continue }
      attributed.addAttribute(.link, value: url, range: match.range)
      attributed.addAttribute(
        .foregroundColor, value: UIColor(Color.accentColor), range: match.range)
    }
    return attributed
  }
}
