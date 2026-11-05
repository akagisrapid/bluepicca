import SwiftUI

struct LanguageFilterView: View {
  @ObservedObject private var manager = LanguageFilterManager.shared
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button {
            manager.allowedLanguages = []
          } label: {
            row(title: String(localized: "すべての言語"), isSelected: !manager.isActive)
          }
        }

        Section {
          ForEach(LanguageFilterManager.candidates, id: \.self) { code in
            Button {
              manager.toggle(code)
            } label: {
              row(
                title: LanguageFilterManager.displayName(code),
                isSelected: manager.allowedLanguages.contains(code))
            }
          }
        } footer: {
          Text("選んだ言語の投稿だけをタイムラインに表示します。言語が設定されていない投稿は常に表示します。")
        }
      }
      .navigationTitle("表示する言語")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") {
            dismiss()
          }
        }
      }
    }
  }

  private func row(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title)
        .foregroundColor(.primary)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark")
          .foregroundColor(.accentColor)
      }
    }
  }
}

#Preview {
  LanguageFilterView()
}
