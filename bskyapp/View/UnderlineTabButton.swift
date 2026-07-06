import SwiftUI

/// 下線付きのタブ切り替えボタン。タイムラインのフィード選択とプロフィールのタブで共通利用する。
struct UnderlineTabButton: View {
  let name: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 0) {
        Text(name)
          .font(.subheadline)
          .fontWeight(isSelected ? .semibold : .regular)
          .foregroundColor(isSelected ? .primary : .secondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
        Rectangle()
          .fill(isSelected ? Color.accentColor : Color.clear)
          .frame(height: 2)
      }
    }
    .buttonStyle(.plain)
  }
}
