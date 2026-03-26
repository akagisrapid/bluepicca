import Foundation

struct ModeratedActor: Identifiable {
    let id = UUID()
    let did: String
    let handle: String
    let displayName: String?
    let avatarUrl: URL?
    let blockUri: String? // ブロック解除に使う URI（ブロックリストのみ）
}

class MuteBlockListViewModel: ObservableObject {
    @Published var mutedActors: [ModeratedActor] = []
    @Published var blockedActors: [ModeratedActor] = []
    @Published var isFetchingMuted = false
    @Published var isFetchingBlocked = false

    init() {
        Task {
            await fetchMuted()
            await fetchBlocked()
        }
    }

    @MainActor
    func fetchMuted() async {
        isFetchingMuted = true
        do {
            let response = try await MuteBlockApi.getMutes()
            mutedActors = response.mutes.map {
                ModeratedActor(
                    did: $0.did,
                    handle: $0.handle,
                    displayName: $0.displayName,
                    avatarUrl: $0.avatar.flatMap { URL(string: $0) },
                    blockUri: nil
                )
            }
        } catch {
            print("getMutes error: \(error)")
        }
        isFetchingMuted = false
    }

    @MainActor
    func fetchBlocked() async {
        isFetchingBlocked = true
        do {
            let response = try await MuteBlockApi.getBlocks()
            blockedActors = response.blocks.map {
                ModeratedActor(
                    did: $0.did,
                    handle: $0.handle,
                    displayName: $0.displayName,
                    avatarUrl: $0.avatar.flatMap { URL(string: $0) },
                    blockUri: $0.viewer?.blocking
                )
            }
        } catch {
            print("getBlocks error: \(error)")
        }
        isFetchingBlocked = false
    }

    @MainActor
    func unmute(actor: ModeratedActor) async {
        do {
            try await MuteBlockApi.unmuteActor(did: actor.did)
            mutedActors.removeAll { $0.did == actor.did }
        } catch {
            print("unmuteActor error: \(error)")
        }
    }

    @MainActor
    func unblock(actor: ModeratedActor) async {
        guard let uri = actor.blockUri else { return }
        do {
            try await MuteBlockApi.unblockActor(uri: uri)
            blockedActors.removeAll { $0.did == actor.did }
        } catch {
            print("unblockActor error: \(error)")
        }
    }
}
