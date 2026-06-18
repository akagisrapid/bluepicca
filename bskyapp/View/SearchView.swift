import SwiftData
import SwiftUI

struct SearchView: View {
  @StateObject private var viewModel: SearchViewModel
  @ObservedObject private var hashtagFeedManager = HashtagFeedManager.shared
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isTextFieldFocused: Bool
  @State private var isShowPostCard = false

  init(initialQuery: String = "") {
    _viewModel = StateObject(wrappedValue: SearchViewModel(initialQuery: initialQuery))
  }

  private var currentHashtag: String? {
    let q = viewModel.query.trimmingCharacters(in: .whitespaces)
    guard q.hasPrefix("#"), q.count > 1 else { return nil }
    return String(q.dropFirst())
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // 検索フォーム
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
          TextField("キーワードまたは #ハッシュタグ", text: $viewModel.query)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isTextFieldFocused)
            .onSubmit {
              Task { await viewModel.search() }
            }
          if !viewModel.query.isEmpty {
            Button(action: {
              viewModel.query = ""
              viewModel.posts = []
            }) {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          } else {
            // # ボタン：ハッシュタグ検索のショートカット
            Button(action: {
              viewModel.query = "#"
              isTextFieldFocused = true
            }) {
              Text("#")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        Divider()

        // 検索結果
        if viewModel.isSearching {
          Spacer()
          ProgressView()
          Spacer()
        } else if let error = viewModel.errorMessage {
          Spacer()
          Text(error)
            .foregroundColor(.secondary)
          Spacer()
        } else if viewModel.posts.isEmpty && !viewModel.query.isEmpty {
          Spacer()
          Text("検索結果がありません")
            .foregroundColor(.secondary)
          Spacer()
        } else if viewModel.posts.isEmpty {
          // 空状態：ハッシュタグ検索の導線
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              // 保存済みハッシュタグフィード
              if !hashtagFeedManager.hashtags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                  Text("フィード登録済み")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                  FlowLayout(spacing: 8) {
                    ForEach(hashtagFeedManager.hashtags, id: \.self) { tag in
                      SavedHashtagChip(tag: tag) {
                        startHashtagSearch(tag)
                      } onDelete: {
                        HashtagFeedManager.shared.remove(tag)
                        ToastManager.shared.show(icon: "minus.circle", text: "#\(tag) をフィードから削除")
                      }
                    }
                  }
                }
              }

              // 検索履歴
              if !viewModel.searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                  HStack {
                    Text("最近の検索")
                      .font(.subheadline)
                      .fontWeight(.semibold)
                      .foregroundColor(.secondary)
                    Spacer()
                    Button("クリア") {
                      viewModel.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                  }
                  FlowLayout(spacing: 8) {
                    ForEach(viewModel.searchHistory, id: \.self) { tag in
                      HistoryChip(tag: tag) {
                        viewModel.query = tag
                        Task { await viewModel.search() }
                      } onDelete: {
                        viewModel.removeFromHistory(tag)
                      }
                    }
                  }
                }
              }

            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
          }
        } else {
          List {
            ForEach(viewModel.posts, id: \.uri) { post in
              let cardViewModel = TimelineCardViewModel(post: post)
              let detailViewModel = PostDetailViewModel(post: post)
              NavigationLink(destination: PostDetailView(viewModel: detailViewModel)) {
                TimelineCardView(viewModel: cardViewModel)
              }
              .buttonStyle(.plain)
              .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
              .onAppear {
                if post.uri == viewModel.posts.last?.uri {
                  Task { await viewModel.loadMore() }
                }
              }
            }
            if viewModel.isLoadingMore {
              HStack {
                Spacer()
                ProgressView()
                Spacer()
              }
              .listRowSeparator(.hidden)
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle(viewModel.query.hasPrefix("#") ? "ハッシュタグ検索" : "検索")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") { dismiss() }
        }
        if let tag = currentHashtag, !viewModel.posts.isEmpty {
          ToolbarItem(placement: .navigationBarLeading) {
            let isSaved = hashtagFeedManager.contains(tag)
            Button {
              if isSaved {
                HashtagFeedManager.shared.remove(tag)
                ToastManager.shared.show(icon: "minus.circle", text: "#\(tag) をフィードから削除")
              } else {
                HashtagFeedManager.shared.add(tag)
                ToastManager.shared.show(icon: "plus.circle.fill", text: "#\(tag) をフィードに追加")
              }
            } label: {
              Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
            }
          }
        }
      }
      .task {
        if !viewModel.query.isEmpty {
          await viewModel.search()
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if viewModel.query.hasPrefix("#") {
          Button(action: { isShowPostCard = true }) {
            Image(systemName: "square.and.pencil")
              .font(.title2)
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(Color.accentColor)
              .clipShape(Circle())
              .shadow(radius: 4)
          }
          .padding(.trailing, 20)
          .padding(.bottom, 28)
        }
      }
      .sheet(isPresented: $isShowPostCard) {
        PostCardView(
          viewModel: PostCardViewModel(text: "\(viewModel.query) "),
          isShowPostCard: $isShowPostCard
        )
      }
    }
  }

  private func startHashtagSearch(_ tag: String) {
    viewModel.query = "#\(tag)"
    Task { await viewModel.search() }
  }
}

private struct SavedHashtagChip: View {
  let tag: String
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Button(action: onTap) {
        HStack(spacing: 2) {
          Image(systemName: "bookmark.fill")
            .font(.system(size: 9))
          Text("#\(tag)")
            .font(.caption)
        }
        .foregroundColor(.accentColor)
      }
      .buttonStyle(.plain)
      Button(action: onDelete) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.leading, 10)
    .padding(.trailing, 6)
    .padding(.vertical, 6)
    .background(Color.accentColor.opacity(0.15))
    .clipShape(Capsule())
  }
}

private struct HistoryChip: View {
  let tag: String
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Button(action: onTap) {
        Text(tag)
          .font(.caption)
          .foregroundColor(.accentColor)
      }
      .buttonStyle(.plain)
      Button(action: onDelete) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.leading, 10)
    .padding(.trailing, 6)
    .padding(.vertical, 6)
    .background(Color.accentColor.opacity(0.1))
    .clipShape(Capsule())
  }
}

private struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 0
    var height: CGFloat = 0
    var x: CGFloat = 0
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > width, x > 0 {
        height += rowHeight + spacing
        x = 0
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    height += rowHeight
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        y += rowHeight + spacing
        x = bounds.minX
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
