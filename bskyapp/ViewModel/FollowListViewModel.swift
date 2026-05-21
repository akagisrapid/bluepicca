import Foundation

enum FollowListType {
  case follows
  case followers
}

class FollowListViewModel: ObservableObject {
  @Published var followItems: [FollowItem] = []
  @Published var followerItems: [FollowerItem] = []
  @Published var isFetching: Bool = false
  @Published var cursor: String?
  @Published var hasMoreData: Bool = true

  private let actor: String
  let listType: FollowListType

  init(actor: String, listType: FollowListType) {
    self.actor = actor
    self.listType = listType
    Task { [weak self] in
      await self?.fetchData()
    }
  }

  @MainActor
  func fetchData() async {
    guard !isFetching && hasMoreData else { return }

    do {
      isFetching = true

      switch listType {
      case .follows:
        let response = try await GetFollowsApi.getFollows(
          param: GetFollowsApiRequest(
            actor: actor,
            limit: 50,
            cursor: cursor
          )
        )
        followItems.append(contentsOf: response.follows)
        cursor = response.cursor
        hasMoreData = response.cursor != nil

      case .followers:
        let response = try await GetFollowersApi.getFollowers(
          param: GetFollowersApiRequest(
            actor: actor,
            limit: 50,
            cursor: cursor
          )
        )
        followerItems.append(contentsOf: response.followers)
        cursor = response.cursor
        hasMoreData = response.cursor != nil
      }

      isFetching = false
    } catch {
      dlog("Error fetching data: \(error)")
      isFetching = false
    }
  }

  @MainActor
  func loadMore() async {
    await fetchData()
  }
}
