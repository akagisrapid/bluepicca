import SwiftUI
import SwiftData

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var isShowPostCard = false

    init(initialQuery: String = "") {
        _viewModel = StateObject(wrappedValue: SearchViewModel(initialQuery: initialQuery))
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
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ハッシュタグ検索")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                HashtagShortcutButton(tag: "Bluesky") {
                                    startHashtagSearch("Bluesky")
                                }
                                HashtagShortcutButton(tag: "日本語") {
                                    startHashtagSearch("日本語")
                                }
                                HashtagShortcutButton(tag: "写真") {
                                    startHashtagSearch("写真")
                                }
                                HashtagShortcutButton(tag: "nowplaying") {
                                    startHashtagSearch("nowplaying")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    Spacer()
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
                    Button("閉じる") { dismiss() }
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

private struct HashtagShortcutButton: View {
    let tag: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
