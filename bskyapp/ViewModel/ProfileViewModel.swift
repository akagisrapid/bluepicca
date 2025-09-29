import Foundation
class ProfileViewModel: ObservableObject {
    @Published var actor: String
    @Published var profile: GetProfileApiResponse = .init(did: "", handle: "", labels: [])
    @Published var isFetching: Bool = false
    @Published var isFollowing: Bool = false
    @Published var followUri: String?
    @Published var isProcessingFollow: Bool = false

    init(actor: String, profile: GetProfileApiResponse) {
        self.actor = actor
        self.profile = profile
        Task {
            await fetchProfile()
        }
    }

    @MainActor
    func fetchProfile() async {
        // キャッシュをチェック
        if let cachedProfile = ProfileCacheManager.shared.getCachedProfile(for: actor) {
            print("Using cached profile data for \(actor)")
            self.profile = cachedProfile
            self.isFollowing = cachedProfile.viewer?.following != nil
            self.followUri = cachedProfile.viewer?.following
            return
        }
        
        do {
            self.isFetching = true
            
            // SafeAPIExecutorを使用してレート制限対応
            let fetchedProfile = try await SafeAPIExecutor.shared.execute(endpoint: "profile") {
                try await GetProfileApi().getProfile(param: .init(actor: self.actor))
            }
            
            self.profile = fetchedProfile
            self.isFollowing = fetchedProfile.viewer?.following != nil
            self.followUri = fetchedProfile.viewer?.following
            
            // プロフィールをキャッシュに保存
            ProfileCacheManager.shared.cacheProfile(fetchedProfile, for: actor)
            
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
                    BatchActionHelper.shared.queueUnfollow(followUri: uri)
                    
                    // ローカル状態を即座に更新
                    self.isFollowing = false
                    self.followUri = nil
                    
                    // プロフィールキャッシュを更新
                    var updatedProfile = self.profile
                    updatedProfile.viewer?.following = nil
                    ProfileCacheManager.shared.cacheProfile(updatedProfile, for: actor)
                    
                    print("Queued unfollow for \(profile.handle)")
                }
            } else {
                // フォローをバッチ処理に追加
                BatchActionHelper.shared.queueFollow(actorDid: profile.did)
                
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
        ProfileCacheManager.shared.clearProfile(for: actor)
        await fetchProfile()
    }
}
