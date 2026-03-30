import SwiftUI

struct MuteWordsView: View {
    @StateObject private var manager = MuteWordManager.shared
    @State private var newWord = ""
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
                                .foregroundColor(newWord.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
                        }
                        .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("新規追加")
                }

                Section {
                    if manager.muteWords.isEmpty {
                        Text("ミュートワードがありません")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(manager.muteWords, id: \.self) { word in
                            Text(word)
                        }
                        .onDelete { offsets in
                            manager.remove(at: offsets)
                        }
                    }
                } header: {
                    Text("ミュート中 (\(manager.muteWords.count))")
                }
            }
            .navigationTitle("ミュートワード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
        manager.add(newWord)
        newWord = ""
    }
}

#Preview {
    MuteWordsView()
}
