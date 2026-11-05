import Foundation

enum SearchScope: String, CaseIterable {
  case posts
  case users

  var label: String {
    switch self {
    case .posts: return String(localized: "投稿")
    case .users: return String(localized: "ユーザー")
    }
  }
}

class SearchViewModel: ObservableObject {
  @Published var query: String
  @Published var scope: SearchScope = .posts
  @Published var posts: [Post] = []
  @Published var actors: [ActorSearchItem] = []
  @Published var isSearching: Bool = false
  @Published var errorMessage: String? = nil
  @Published var searchHistory: [String] = []

  private var searchCursor: String?
  private var actorCursor: String?
  @Published var isLoadingMore: Bool = false

  private let historyKey = "recentSearchHistory"
  private let maxHistoryCount = 20

  init(initialQuery: String = "") {
    self.query = initialQuery
    self.searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
  }

  /// ハッシュタグは投稿の検索にしか使えない
  var isHashtagQuery: Bool {
    query.trimmingCharacters(in: .whitespaces).hasPrefix("#")
  }

  /// 実際に検索する種類。"#" で始まれば投稿、"@" で始まればユーザー
  var effectiveScope: SearchScope {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("#") { return .posts }
    if trimmed.hasPrefix("@") { return .users }
    return scope
  }

  var hasResults: Bool {
    effectiveScope == .posts ? !posts.isEmpty : !actors.isEmpty
  }

  func clearResults() {
    posts = []
    actors = []
    searchCursor = nil
    actorCursor = nil
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

  /// ユーザー検索に渡す語。"@alice.bsky.social" の "@" は外す
  static func actorQuery(_ query: String) -> String {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
  }

  @MainActor
  func search() async {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    saveToHistory(trimmed)

    isSearching = true
    errorMessage = nil
    clearResults()

    do {
      switch effectiveScope {
      case .posts:
        let response = try await SearchPostsApi().searchPosts(query: trimmed)
        posts = response.posts
        searchCursor = response.cursor
      case .users:
        let actorQuery = Self.actorQuery(trimmed)
        guard !actorQuery.isEmpty else { break }
        let response = try await SearchActorsApi().searchActors(query: actorQuery)
        actors = response.actors
        actorCursor = response.cursor
      }
    } catch {
      errorMessage = String(localized: "検索に失敗しました")
      dlog("SearchViewModel: search error: \(error)")
    }
    isSearching = false
  }

  @MainActor
  func loadMore() async {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !isLoadingMore else { return }

    switch effectiveScope {
    case .posts:
      guard let cursor = searchCursor else { return }
      isLoadingMore = true
      do {
        let response = try await SearchPostsApi().searchPosts(query: trimmed, cursor: cursor)
        posts.append(contentsOf: response.posts)
        searchCursor = response.cursor
      } catch {
        dlog("SearchViewModel: loadMore error: \(error)")
      }
    case .users:
      guard let cursor = actorCursor else { return }
      isLoadingMore = true
      do {
        let response = try await SearchActorsApi().searchActors(
          query: Self.actorQuery(trimmed), cursor: cursor)
        actors.append(contentsOf: response.actors)
        actorCursor = response.cursor
      } catch {
        dlog("SearchViewModel: loadMore error: \(error)")
      }
    }
    isLoadingMore = false
  }
}
