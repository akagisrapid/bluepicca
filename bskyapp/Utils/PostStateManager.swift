import Foundation

/// ポストのいいね・リポスト状態を永続化するマネージャー
class PostStateManager {
    static let shared = PostStateManager()

    private let userDefaults = UserDefaults.standard
    private let likedPostsKey = "likedPosts"
    private let repostedPostsKey = "repostedPosts"
    /// UserDefaults に保持するエントリの上限数。タイムラインから消えた古い投稿が際限なく蓄積されないようにする。
    private let maxEntryCount = 500

    private init() {}

    // MARK: - いいね状態の管理

    /// ポストにいいねしたことを記録
    func setLiked(postUri: String, likeUri: String) {
        var likedPosts = getLikedPosts()
        likedPosts[postUri] = likeUri
        saveLikedPosts(likedPosts)
    }

    /// ポストのいいねを取り消したことを記録
    func removeLiked(postUri: String) {
        var likedPosts = getLikedPosts()
        likedPosts.removeValue(forKey: postUri)
        saveLikedPosts(likedPosts)
    }

    /// ポストがいいねされているかチェック
    func isLiked(postUri: String) -> Bool {
        let likedPosts = getLikedPosts()
        return likedPosts[postUri] != nil
    }

    /// ポストのいいねURIを取得
    func getLikeUri(postUri: String) -> String? {
        let likedPosts = getLikedPosts()
        return likedPosts[postUri]
    }

    private func getLikedPosts() -> [String: String] {
        return userDefaults.dictionary(forKey: likedPostsKey) as? [String: String] ?? [:]
    }

    private func saveLikedPosts(_ likedPosts: [String: String]) {
        let trimmed = likedPosts.count > maxEntryCount
            ? Dictionary(uniqueKeysWithValues: Array(likedPosts.prefix(maxEntryCount)))
            : likedPosts
        userDefaults.set(trimmed, forKey: likedPostsKey)
    }

    // MARK: - リポスト状態の管理

    /// ポストをリポストしたことを記録
    func setReposted(postUri: String, repostUri: String) {
        var repostedPosts = getRepostedPosts()
        repostedPosts[postUri] = repostUri
        saveRepostedPosts(repostedPosts)
    }

    /// ポストのリポストを取り消したことを記録
    func removeReposted(postUri: String) {
        var repostedPosts = getRepostedPosts()
        repostedPosts.removeValue(forKey: postUri)
        saveRepostedPosts(repostedPosts)
    }

    /// ポストがリポストされているかチェック
    func isReposted(postUri: String) -> Bool {
        let repostedPosts = getRepostedPosts()
        return repostedPosts[postUri] != nil
    }

    /// ポストのリポストURIを取得
    func getRepostUri(postUri: String) -> String? {
        let repostedPosts = getRepostedPosts()
        return repostedPosts[postUri]
    }

    private func getRepostedPosts() -> [String: String] {
        return userDefaults.dictionary(forKey: repostedPostsKey) as? [String: String] ?? [:]
    }

    private func saveRepostedPosts(_ repostedPosts: [String: String]) {
        let trimmed = repostedPosts.count > maxEntryCount
            ? Dictionary(uniqueKeysWithValues: Array(repostedPosts.prefix(maxEntryCount)))
            : repostedPosts
        userDefaults.set(trimmed, forKey: repostedPostsKey)
    }

    // MARK: - サーバー状態との同期

    /// サーバーから取得したポスト一覧でローカル状態を同期する
    /// タイムライン取得後に呼び出すことで、サーバーの正しい状態をローカルに反映する
    func syncWithServerState(posts: [Post]) {
        var likedPosts = getLikedPosts()
        var repostedPosts = getRepostedPosts()
        var changed = false

        for post in posts {
            guard let postUri = post.uri else { continue }

            // いいね状態の同期
            if let serverLikeUri = post.viewer?.like {
                // サーバーではいいね済み → ローカルも更新
                if likedPosts[postUri] != serverLikeUri {
                    likedPosts[postUri] = serverLikeUri
                    changed = true
                }
            } else {
                // サーバーではいいねしていない → ローカルのpending状態を除去
                if let localUri = likedPosts[postUri], localUri.hasPrefix("pending_") {
                    likedPosts.removeValue(forKey: postUri)
                    changed = true
                } else if likedPosts[postUri] != nil {
                    // サーバーで解除されている（他デバイスでの操作など）
                    likedPosts.removeValue(forKey: postUri)
                    changed = true
                }
            }

            // リポスト状態の同期
            if let serverRepostUri = post.viewer?.repost {
                if repostedPosts[postUri] != serverRepostUri {
                    repostedPosts[postUri] = serverRepostUri
                    changed = true
                }
            } else {
                if let localUri = repostedPosts[postUri], localUri.hasPrefix("pending_") {
                    repostedPosts.removeValue(forKey: postUri)
                    changed = true
                } else if repostedPosts[postUri] != nil {
                    repostedPosts.removeValue(forKey: postUri)
                    changed = true
                }
            }
        }

        if changed {
            saveLikedPosts(likedPosts)
            saveRepostedPosts(repostedPosts)
        }
    }

    // MARK: - データクリア

    /// 全ての状態をクリア（ログアウト時などに使用）
    func clearAllStates() {
        userDefaults.removeObject(forKey: likedPostsKey)
        userDefaults.removeObject(forKey: repostedPostsKey)
    }
}
