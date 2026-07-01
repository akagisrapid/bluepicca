import SwiftData
import SwiftUI

struct DraftsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \PostDraft.updatedAt, order: .reverse) private var drafts: [PostDraft]

  var onSelect: (PostDraft) -> Void

  var body: some View {
    NavigationStack {
      Group {
        if drafts.isEmpty {
          ContentUnavailableView(
            "下書きがありません",
            systemImage: "doc.text",
            description: Text("ポスト画面で下書きを保存できます")
          )
        } else {
          List {
            ForEach(drafts) { draft in
              Button {
                onSelect(draft)
                dismiss()
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(draft.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                  Text(draft.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
              }
            }
            .onDelete(perform: deleteDrafts)
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("下書き")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if !drafts.isEmpty {
          ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") { dismiss() }
        }
      }
    }
  }

  private func deleteDrafts(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(drafts[index])
    }
  }
}
