import Foundation

@MainActor
class LikesViewModel: ObservableObject {
  @Published var likes: [Like] = []
  @Published var targetPost: Post?
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let getLikesApi = GetLikesApi()
  private let getPostThreadApi = GetPostThreadApi()

  func fetchLikes(uri: String, cid: String? = nil) async {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    do {
      let request = GetLikesApiRequest(
        uri: uri,
        cid: cid,
        limit: 50,
        cursor: nil
      )

      let response = try await getLikesApi.getLikes(param: request)
      likes = response.likes
    } catch {
      errorMessage = error.userFacingMessage
      dlog("Error fetching likes: \(error)")
    }

    isLoading = false
  }

  func fetchTargetPost(uri: String) async {
    do {
      let response = try await getPostThreadApi.getPostThread(uri: uri)
      targetPost = response.thread.post
    } catch {
      dlog("Error fetching target post: \(error)")
    }
  }

  func clearLikes() {
    likes = []
    targetPost = nil
    errorMessage = nil
  }
}
