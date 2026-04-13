import Foundation
class ProfileViewModel: ObservableObject {
    @Published var actor: String
    @Published var profile: GetProfileApiResponse = .init(did: "", handle: "", labels: [])
    @Published var isFetching: Bool = false
    @Published var isFollowing: Bool = false
    @Published var followUri: String?
    @Published var isProcessingFollow: Bool = false

    // ミュート・ブロック状態
    @Published var isMuted: Bool = false
    @Published var isBlocked: Bool = false
    @Published var blockUri: String? = nil
    @Published var isProcessingMuteBlock: Bool = false

    // ポスト関連のプロパティ
    @Published var posts: [FeedItem] = []
    @Published var isFetchingPosts: Bool = false
    @Published var postsCursor: String?

    init(actor: String, profile: GetProfileApiResponse) {
        self.actor = actor
        self.profile = profile
        Task {
            await fetchProfile()
            await fetchPosts()
        }
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
        
        do {
            if isFollowing {
                // アンフォローをバッチ処理に追加
                if let uri = followUri {
                    
                    // ローカル状態を即座に更新
                    self.isFollowing = false
                    self.followUri = nil
                    
                    // プロフィールキャッシュを更新
                    var updatedProfile = self.profile
                    updatedProfile.viewer?.following = nil
                    
                    print("Queued unfollow for \(profile.handle)")
                }
            } else {
                
                // ローカル状態を即座に更新（仮のURI）
                self.isFollowing = true
                self.followUri = "pending_follow_\(profile.did)"
                
                print("Queued follow for \(profile.handle)")
            }
        } catch {
            print("Error toggling follow: \(error)")
        }
        
        isProcessingFollow = false
    }
    
    /// プロフィールキャッシュを強制更新
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
    
    /// ユーザーのポストを取得
    @MainActor
    func fetchPosts() async {
        guard !isFetchingPosts else { return }
        
        do {
            self.isFetchingPosts = true
            
            let feedResponse = try await GetAuthorFeedApi().getAuthorFeed(
                actor: self.actor,
                limit: 50,
                cursor: self.postsCursor
            )
            
            if self.postsCursor == nil {
                // 初回取得の場合は置き換え
                self.posts = feedResponse.feed
            } else {
                // 追加読み込みの場合は追加
                self.posts.append(contentsOf: feedResponse.feed)
            }
            
            self.postsCursor = feedResponse.cursor
            self.isFetchingPosts = false
            
        } catch {
            self.isFetchingPosts = false
            print("Error fetching posts: \(error)")
        }
    }
    
    /// ポストを更新（リフレッシュ）
    @MainActor
    func refreshPosts() async {
        self.posts = []
        self.postsCursor = nil
        await fetchPosts()
    }
}
