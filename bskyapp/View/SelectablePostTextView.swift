import SwiftUI
import UIKit

/// UITextViewベースの本文表示。長押しでのテキスト選択・コピーに対応しつつ、
/// ハッシュタグのタップ遷移も維持する（SwiftUIのText.textSelectionはリンク付き
/// AttributedStringと組み合わせると文字単位の選択ができないための代替）。
struct SelectablePostTextView: UIViewRepresentable {
  let text: String
  var font: UIFont = .preferredFont(forTextStyle: .title3)
  let onHashtagTap: (String) -> Void

  func makeUIView(context: Context) -> AutoSizingTextView {
    let textView = AutoSizingTextView()
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

  func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
    uiView.attributedText = buildAttributedString()
    uiView.invalidateIntrinsicContentSize()
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

/// 幅に応じて高さを自己解決するUITextView（SwiftUIレイアウトへの組み込み用）
final class AutoSizingTextView: UITextView {
  override var intrinsicContentSize: CGSize {
    let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
    let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    invalidateIntrinsicContentSize()
  }
}
