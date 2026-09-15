import SwiftUI

// MARK: - ポスト本文からミュートワードを即時追加するシート

struct MuteWordQuickAddView: View {
  let text: String
  @ObservedObject private var manager = MuteWordManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var customWord = ""

  private var candidateWords: [String] {
    let separators = CharacterSet(charactersIn: " \n\t、。！？!?,.\"'「」『』()（）[]【】/\\:;")
    var seen = Set<String>()
    var result: [String] = []
    for token in text.components(separatedBy: separators) {
      let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.count >= 2, !trimmed.hasPrefix("http"), !seen.contains(trimmed) else {
        continue
      }
      seen.insert(trimmed)
      result.append(trimmed)
    }
    return result
  }

  private func addWord(_ word: String) {
    let trimmed = word.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    manager.add(trimmed)
    ToastManager.shared.show(icon: "text.badge.xmark", text: "ミュートワードに追加")
    dismiss()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("この投稿からミュートワードを追加")
        .font(.headline)
        .padding(.top, 20)
        .padding(.horizontal, 20)

      if candidateWords.isEmpty {
        Text("候補となる単語が見つかりませんでした。下から直接入力してください。")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal, 20)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(candidateWords, id: \.self) { word in
              Button {
                addWord(word)
              } label: {
                HStack {
                  Text(word)
                    .foregroundColor(.primary)
                  Spacer()
                  Image(systemName: "plus.circle")
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
              }
              Divider()
                .padding(.leading, 20)
            }
          }
        }
      }

      HStack {
        TextField("直接入力してミュート", text: $customWord)
          .submitLabel(.done)
          .onSubmit { addWord(customWord) }
        Button {
          addWord(customWord)
        } label: {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(
              customWord.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
        }
        .disabled(customWord.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
  }
}
