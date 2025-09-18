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
        do {
            self.isFetching = true
            let fetchedProfile = try await GetProfileApi().getProfile(param: .init(actor: actor))
            self.profile = fetchedProfile
            self.isFollowing = fetchedProfile.viewer?.following != nil
            self.followUri = fetchedProfile.viewer?.following
            self.isFetching = false
        } catch {
            print(error)
        }
    }

    @MainActor
    func toggleFollow() async {
        guard !isProcessingFollow else { return }
        isProcessingFollow = true
        do {
            if isFollowing {
                // アンフォロー
                if let uri = followUri {
                    _ = try await DeleteRecordApi.deleteRecord(uri: uri)
                    print("Successfully unfollowed \(profile.handle)")
                }
            } else {
                // フォロー
                _ = try await CreateFollowApi.createFollow(actorDid: profile.did)
                print("Successfully followed \(profile.handle)")
            }
            await fetchProfile() // 状態を更新するためにプロフィールを再フェッチ
        } catch {
            print("Error toggling follow: \(error)")
        }
        isProcessingFollow = false
    }
}
