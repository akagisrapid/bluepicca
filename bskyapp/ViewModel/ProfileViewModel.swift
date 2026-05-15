import Foundation

class ProfileViewModel: ObservableObject {
  @Published var actor: String
  @Published var profile: GetProfileApiResponse = .init(did: "", handle: "", labels: [])
  @Published var isFetching: Bool = false
  @Published var isFollowing: Bool = false
  @Published var followUri: String?
  @Published var isProcessingFollow: Bool = false
  @Published var isOwnProfile: Bool = false

  // ミュート・ブロック状態
  @Published var isMuted: Bool = false
  @Published var isBlocked: Bool = false
  @Published var blockUri: String? = nil
  @Published var isProcessingMuteBlock: Bool = false

  // 投稿
  @Published var posts: [FeedItem] = []
  @Published var isFetchingPosts: Bool = false
  @Published var postsCursor: String?

  // フォロワー
  @Published var followers: [FollowerItem] = []
  @Published var isFetchingFollowers: Bool = false
  @Published var followersCursor: String?

  // フォロー中
  @Published var following: [FollowItem] = []
  @Published var isFetchingFollowing: Bool = false
  @Published var followingCursor: String?

  // いいね（自分のプロフィールのみ）
  @Published var likedPosts: [FeedItem] = []
  @Published var isFetchingLikes: Bool = false
  @Published var likesCursor: String?

  init(actor: String, profile: GetProfileApiResponse) {
    self.actor = actor
    self.profile = profile
  }

  @MainActor
  func fetchProfile() async {
    do {
      self.isFetching = true
      let fetchedProfile = try await GetProfileApi().getProfile(param: .init(actor: self.actor))
      self.profile = fetchedProfile
      self.isFollowing = fetchedProfile.viewer?.following != nil
      self.followUri = fetchedProfile.viewer?.following
      self.isMuted = fetchedProfile.viewer?.muted ?? false
      self.isBlocked = fetchedProfile.viewer?.blocking != nil
      self.blockUri = fetchedProfile.viewer?.blocking
      if let myDid = SessionManager.shared.currentDid {
        self.isOwnProfile = myDid == fetchedProfile.did
      }
      self.isFetching = false
    } catch {
      self.isFetching = false
      print(error)
    }
  }

  @MainActor
  func toggleFollow() async {
    guard !isProcessingFollow else { return }
    isProcessingFollow = true
    defer { isProcessingFollow = false }
    if isFollowing {
      if let uri = followUri {
        self.isFollowing = false
        self.followUri = nil
        var updatedProfile = self.profile
        updatedProfile.viewer?.following = nil
        print("Queued unfollow for \(profile.handle)")
      }
    } else {
      self.isFollowing = true
      self.followUri = "pending_follow_\(profile.did)"
      print("Queued follow for \(profile.handle)")
    }
  }

  @MainActor
  func forceRefreshProfile() async {
    await fetchProfile()
  }

  // MARK: - ミュート

  @MainActor
  func toggleMute() async {
    guard !isProcessingMuteBlock else { return }
    isProcessingMuteBlock = true
    do {
      if isMuted {
        try await MuteBlockApi.unmuteActor(did: profile.did)
        isMuted = false
      } else {
        try await MuteBlockApi.muteActor(did: profile.did)
        isMuted = true
      }
    } catch {
      print("toggleMute error: \(error)")
    }
    isProcessingMuteBlock = false
  }

  // MARK: - ブロック

  @MainActor
  func toggleBlock() async {
    guard !isProcessingMuteBlock else { return }
    isProcessingMuteBlock = true
    do {
      if isBlocked, let uri = blockUri {
        try await MuteBlockApi.unblockActor(uri: uri)
        isBlocked = false
        blockUri = nil
      } else {
        let uri = try await MuteBlockApi.blockActor(did: profile.did)
        isBlocked = true
        blockUri = uri
      }
    } catch {
      print("toggleBlock error: \(error)")
    }
    isProcessingMuteBlock = false
  }

  // MARK: - 投稿

  @MainActor
  func fetchPosts(loadMore: Bool = false) async {
    guard !isFetchingPosts else { return }
    isFetchingPosts = true
    defer { isFetchingPosts = false }
    do {
      let cursor = loadMore ? postsCursor : nil
      let res = try await GetAuthorFeedApi().getAuthorFeed(
        actor: self.actor, limit: 50, cursor: cursor)
      if loadMore {
        posts.append(contentsOf: res.feed)
      } else {
        posts = res.feed
      }
      postsCursor = res.cursor
    } catch {
      print("fetchPosts error: \(error)")
    }
  }

  @MainActor
  func refreshPosts() async {
    posts = []
    postsCursor = nil
    await fetchPosts()
  }

  // MARK: - フォロワー

  @MainActor
  func fetchFollowers(loadMore: Bool = false) async {
    guard !isFetchingFollowers else { return }
    isFetchingFollowers = true
    defer { isFetchingFollowers = false }
    do {
      let cursor = loadMore ? followersCursor : nil
      let res = try await GetFollowersApi.getFollowers(
        param: .init(actor: actor, limit: 50, cursor: cursor))
      if loadMore {
        followers.append(contentsOf: res.followers)
      } else {
        followers = res.followers
      }
      followersCursor = res.cursor
    } catch {
      print("fetchFollowers error: \(error)")
    }
  }

  // MARK: - フォロー中

  @MainActor
  func fetchFollowing(loadMore: Bool = false) async {
    guard !isFetchingFollowing else { return }
    isFetchingFollowing = true
    defer { isFetchingFollowing = false }
    do {
      let cursor = loadMore ? followingCursor : nil
      let res = try await GetFollowsApi.getFollows(
        param: .init(actor: actor, limit: 50, cursor: cursor))
      if loadMore {
        following.append(contentsOf: res.follows)
      } else {
        following = res.follows
      }
      followingCursor = res.cursor
    } catch {
      print("fetchFollowing error: \(error)")
    }
  }

  // MARK: - いいね

  @MainActor
  func fetchLikedPosts(loadMore: Bool = false) async {
    guard !isFetchingLikes else { return }
    isFetchingLikes = true
    defer { isFetchingLikes = false }
    do {
      let cursor = loadMore ? likesCursor : nil
      let res = try await GetActorLikesApi().getActorLikes(
        param: .init(actor: actor, limit: 20, cursor: cursor))
      if loadMore {
        likedPosts.append(contentsOf: res.feed)
      } else {
        likedPosts = res.feed
      }
      likesCursor = res.cursor
    } catch {
      print("fetchLikedPosts error: \(error)")
    }
  }
}
