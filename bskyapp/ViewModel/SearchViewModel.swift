import Foundation

class SearchViewModel: ObservableObject {
  @Published var query: String
  @Published var posts: [Post] = []
  @Published var isSearching: Bool = false
  @Published var errorMessage: String? = nil
  @Published var searchHistory: [String] = []

  private var searchCursor: String?
  @Published var isLoadingMore: Bool = false

  private let historyKey = "recentSearchHistory"
  private let maxHistoryCount = 20

  init(initialQuery: String = "") {
    self.query = initialQuery
    self.searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
  }

  func removeFromHistory(_ tag: String) {
    searchHistory.removeAll { $0 == tag }
    UserDefaults.standard.set(searchHistory, forKey: historyKey)
  }

  func clearHistory() {
    searchHistory = []
    UserDefaults.standard.set(searchHistory, forKey: historyKey)
  }

  private func saveToHistory(_ query: String) {
    var history = searchHistory
    history.removeAll { $0 == query }
    history.insert(query, at: 0)
    if history.count > maxHistoryCount {
      history = Array(history.prefix(maxHistoryCount))
    }
    searchHistory = history
    UserDefaults.standard.set(history, forKey: historyKey)
  }

  @MainActor
  func search() async {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    saveToHistory(trimmed)

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
      dlog("SearchViewModel: search error: \(error)")
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
      dlog("SearchViewModel: loadMore error: \(error)")
    }
    isLoadingMore = false
  }
}
