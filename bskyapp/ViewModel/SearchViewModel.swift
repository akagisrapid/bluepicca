import Foundation

class SearchViewModel: ObservableObject {
    @Published var query: String
    @Published var posts: [Post] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String? = nil

    private var searchCursor: String?
    @Published var isLoadingMore: Bool = false

    init(initialQuery: String = "") {
        self.query = initialQuery
    }

    @MainActor
    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        posts = []
        searchCursor = nil

        do {
            let response = try await SearchPostsApi().searchPosts(query: trimmed)
            posts = response.posts
            searchCursor = response.cursor
        } catch {
            errorMessage = "検索に失敗しました"
            print("SearchViewModel: search error: \(error)")
        }
        isSearching = false
    }

    @MainActor
    func loadMore() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isLoadingMore, let cursor = searchCursor else { return }

        isLoadingMore = true
        do {
            let response = try await SearchPostsApi().searchPosts(query: trimmed, cursor: cursor)
            posts.append(contentsOf: response.posts)
            searchCursor = response.cursor
        } catch {
            print("SearchViewModel: loadMore error: \(error)")
        }
        isLoadingMore = false
    }
}
