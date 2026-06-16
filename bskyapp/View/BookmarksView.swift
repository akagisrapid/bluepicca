import SwiftData
import SwiftUI

struct BookmarksView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \BookmarkedPost.createdAt, order: .reverse) private var bookmarks: [BookmarkedPost]

  var body: some View {
    NavigationStack {
      Group {
        if bookmarks.isEmpty {
          ContentUnavailableView(
            "ブックマークなし",
            systemImage: "bookmark",
            description: Text("ポストのブックマークアイコンをタップすると、ここに表示されます")
          )
        } else {
          List {
            ForEach(bookmarks) { bookmark in
              BookmarkRowView(bookmark: bookmark)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onDelete { indexSet in
              indexSet.map { bookmarks[$0] }.forEach { modelContext.delete($0) }
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("ブックマーク")
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
}

private struct BookmarkRowView: View {
  let bookmark: BookmarkedPost

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text(
          bookmark.authorDisplayName.isEmpty ? bookmark.authorHandle : bookmark.authorDisplayName
        )
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.primary)
        .lineLimit(1)
        Text("@\(bookmark.authorHandle)")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
        Spacer()
        Text(bookmark.createdAt, style: .relative)
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      if !bookmark.text.isEmpty {
        Text(bookmark.text)
          .font(.body)
          .foregroundColor(.primary)
          .lineLimit(4)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }
}
