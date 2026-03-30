import SwiftUI
import SwiftData

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss

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
                } else {
                    List {
                        ForEach(viewModel.posts, id: \.uri) { post in
                            let cardViewModel = TimelineCardViewModel(post: post)
                            let detailViewModel = PostDetailViewModel(post: post)
                            ZStack {
                                NavigationLink(destination: PostDetailView(viewModel: detailViewModel)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                TimelineCardView(viewModel: cardViewModel)
                            }
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
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
