import SwiftUI

struct MuteWordsView: View {
  @StateObject private var manager = MuteWordManager.shared
  @State private var newWord = ""
  @State private var target: MuteWord.Target = .content
  @State private var duration: MuteDuration = .forever
  @Environment(\.dismiss) private var dismiss
  @Environment(\.editMode) private var editMode

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack {
            TextField("ミュートワードを追加", text: $newWord)
              .submitLabel(.done)
              .onSubmit { addWord() }
            Button(action: addWord) {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(
                  newWord.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
            }
            .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          Picker("対象", selection: $target) {
            ForEach(MuteWord.Target.allCases, id: \.self) { Text($0.label).tag($0) }
          }
          .pickerStyle(.segmented)
          MuteDurationPicker(duration: $duration)
        } header: {
          Text("新規追加")
        }

        Section {
          if manager.entries.isEmpty {
            Text("ミュートワードがありません")
              .foregroundColor(.secondary)
              .font(.subheadline)
          } else {
            ForEach(manager.entries) { word in
              VStack(alignment: .leading, spacing: 2) {
                Text(word.value)
                MuteWordDetail(word: word)
              }
            }
            .onDelete { offsets in
              manager.remove(at: offsets)
            }
          }
        } header: {
          Text("ミュート中 (\(manager.entries.count))")
        }
      }
      .navigationTitle("ミュートワード")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            editMode?.wrappedValue = editMode?.wrappedValue.isEditing == true ? .inactive : .active
          } label: {
            Image(systemName: editMode?.wrappedValue.isEditing == true ? "checkmark" : "pencil")
          }
        }
      }
    }
  }

  private func addWord() {
    manager.add(newWord, target: target, duration: duration.interval)
    newWord = ""
  }
}

/// Bluesky 公式と同じ選択肢
enum MuteDuration: CaseIterable {
  case day, week, month, forever

  var interval: TimeInterval? {
    switch self {
    case .day: 24 * 60 * 60
    case .week: 7 * 24 * 60 * 60
    case .month: 30 * 24 * 60 * 60
    case .forever: nil
    }
  }

  var label: LocalizedStringResource {
    switch self {
    case .day: "24時間"
    case .week: "7日"
    case .month: "30日"
    case .forever: "無期限"
    }
  }
}

struct MuteDurationPicker: View {
  @Binding var duration: MuteDuration

  var body: some View {
    Picker("期間", selection: $duration) {
      ForEach(MuteDuration.allCases, id: \.self) { Text($0.label).tag($0) }
    }
  }
}

/// 一覧の 2 行目。「タグのみ · 11/30 8:00まで」のように対象と期限を出す
private struct MuteWordDetail: View {
  let word: MuteWord

  var body: some View {
    HStack(spacing: 4) {
      Text(word.target.label)
      if let expiresAt = word.expiresAt {
        Text("·")
        if word.isActive() {
          Text("\(expiresAt.formatted(.dateTime.month().day().hour().minute()))まで")
        } else {
          Text("期限切れ")
        }
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}

#Preview {
  MuteWordsView()
}
