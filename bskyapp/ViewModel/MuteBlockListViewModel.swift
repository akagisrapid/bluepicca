import Foundation

struct ModeratedActor: Identifiable {
  let id = UUID()
  let did: String
  let handle: String
  let displayName: String?
  let avatarUrl: URL?
  let blockUri: String?  // ブロック解除に使う URI（ブロックリストのみ）
}

class MuteBlockListViewModel: ObservableObject {
  @Published var mutedActors: [ModeratedActor] = []
  @Published var blockedActors: [ModeratedActor] = []
  @Published var isFetchingMuted = false
  @Published var isFetchingBlocked = false

  init() {}

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
      MutedUsersManager.shared.reconcile(withServerMutedDIDs: Set(mutedActors.map { $0.did }))
    } catch {
      dlog("getMutes error: \(error)")
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
      dlog("getBlocks error: \(error)")
    }
    isFetchingBlocked = false
  }

  // スワイプ操作と同じトランザクション内で即座に行毎削除する（Task内に遅延させるとList側の
  // 削除アニメーションと競合し、行が一瞬消えてから復活して見える）
  @MainActor
  func unmuteOptimistically(actor: ModeratedActor) {
    let previousActors = mutedActors
    mutedActors.removeAll { $0.did == actor.did }
    MutedUsersManager.shared.remove(did: actor.did)
    Task { await unmute(actor: actor, previousActors: previousActors) }
  }

  @MainActor
  private func unmute(actor: ModeratedActor, previousActors: [ModeratedActor]) async {
    do {
      try await MuteBlockApi.unmuteActor(did: actor.did)
    } catch {
      dlog("unmuteActor error: \(error)")
      mutedActors = previousActors
      MutedUsersManager.shared.add(did: actor.did)
      ToastManager.shared.show(
        icon: "exclamationmark.triangle",
        text: "ミュート解除失敗: \(error.localizedDescription)",
        durationMilliseconds: 4000
      )
    }
  }

  @MainActor
  func unblock(actor: ModeratedActor) async {
    guard let uri = actor.blockUri else { return }
    do {
      try await MuteBlockApi.unblockActor(uri: uri)
      blockedActors.removeAll { $0.did == actor.did }
    } catch {
      dlog("unblockActor error: \(error)")
    }
  }
}
