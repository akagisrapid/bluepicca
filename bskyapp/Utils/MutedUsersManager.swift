import Foundation

// MARK: - ミュート操作の即時反映用ローカルキャッシュ
// app.bsky.graph.muteActor はサーバー側の状態のため、TLの既存フィード配列には
// 反映が遅れる。ミュート/ミュート解除の直後にTLへ即座に反映するためのオーバーレイ。
class MutedUsersManager: ObservableObject {
  static let shared = MutedUsersManager()
  private let key = "locallyMutedDIDs"

  @Published var mutedDIDs: Set<String>

  private init() {
    let array = UserDefaults.standard.stringArray(forKey: key) ?? []
    mutedDIDs = Set(array)
  }

  func add(did: String) {
    mutedDIDs.insert(did)
    save()
  }

  func remove(did: String) {
    mutedDIDs.remove(did)
    save()
  }

  func isMuted(_ did: String) -> Bool {
    mutedDIDs.contains(did)
  }

  // サーバーの正規リスト（getMutes）で上書きし、通信失敗等で残った「幽霊ミュート」を解消する
  func reconcile(withServerMutedDIDs serverDIDs: Set<String>) {
    mutedDIDs = serverDIDs
    save()
  }

  private func save() {
    UserDefaults.standard.set(Array(mutedDIDs), forKey: key)
  }
}
