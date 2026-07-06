import SwiftUI

// MARK: - 背景色ピッカーシート

struct HighlightColorPickerView: View {
  let did: String
  let authorName: String
  @ObservedObject private var highlightManager = UserHighlightManager.shared
  @Environment(\.dismiss) private var dismiss

  private let columns = Array(repeating: GridItem(.flexible()), count: 3)

  var body: some View {
    VStack(spacing: 20) {
      Text("\(authorName) の背景色")
        .font(.headline)
        .padding(.top, 20)

      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(UserHighlightManager.presetColors, id: \.hex) { item in
          let isSelected = highlightManager.highlights[did] == item.hex
          Button {
            highlightManager.set(did: did, hex: item.hex)
            dismiss()
          } label: {
            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: item.hex))
                .frame(height: 44)
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                )
              Text(item.label)
                .font(.caption2)
                .foregroundColor(.primary)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 24)

      if highlightManager.hasHighlight(for: did) {
        Button(role: .destructive) {
          highlightManager.remove(did: did)
          dismiss()
        } label: {
          Text("背景色を削除")
            .font(.subheadline)
        }
      }

      Spacer()
    }
  }
}
