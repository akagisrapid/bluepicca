import SwiftUI
import SwiftData

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
                                DraftRowView(draft: draft)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                if !drafts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        for index in offsets {
            DraftImageStore.deleteAll(filenames: drafts[index].imageFilenames)
            modelContext.delete(drafts[index])
        }
    }
}

private struct DraftRowView: View {
    let draft: PostDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !draft.text.isEmpty {
                Text(draft.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            if !draft.imageFilenames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(draft.imageFilenames, id: \.self) { filename in
                            if let image = DraftImageStore.load(filename: filename) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }

            Text(draft.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
