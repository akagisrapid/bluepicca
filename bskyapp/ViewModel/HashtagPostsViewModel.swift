import Foundation

class HashtagPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isFetching: Bool = false
    @Published var isShowPostCard: Bool = false

    let hashtag: String

    init(hashtag: String) {
        self.hashtag = hashtag
    }

    @MainActor
    func fetchPosts() async {
        isFetching = true
        do {
            let request = SearchPostsRequest(q: "#\(hashtag)", limit: 30, cursor: nil)
            let response = try await SearchPostsApi().searchPosts(param: request)
            posts = response.posts
        } catch {
            print("Hashtag search error: \(error)")
        }
        isFetching = false
    }
}
