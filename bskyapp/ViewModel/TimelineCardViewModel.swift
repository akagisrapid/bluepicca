import Foundation

class TimelineCardViewModel: ObservableObject{
    @Published var post: Post
    @Published var reason: Reason?
    @Published var isLiking: Bool = false
    @Published var isReposting: Bool = false
    
    init(post: Post, reason: Reason? = nil) {
        self.post = post
        self.reason = reason
        
        // 永続化された状態を復元
        restorePersistedStates()
    }
    var authorName: String{
        post.author?.displayName ?? ""
    }
    var text: String{
        post.record?.text ?? ""
    }
    var likeCount: Int{
        post.likeCount ?? 0
    }
    var postedTimeRelative: String{
        let postTime = post.record?.createdAt?.parseToDateRemovingMilliseconds
        return postTime?.relativeDateString ?? ""
    }
    
    // リポスト情報関連のプロパティ
    var isRepost: Bool {
        return reason != nil
    }
    
    var repostAuthorName: String {
        return reason?.by.displayName ?? reason?.by.handle ?? ""
    }
    
    var repostAuthorHandle: String {
        return reason?.by.handle ?? ""
    }
    
    // MARK: - 永続化された状態の管理
    
    /// 永続化された状態を復元
    private func restorePersistedStates() {
        guard let postUri = post.uri else { return }
        
        // 永続化されたいいね状態を復元
        if PostStateManager.shared.isLiked(postUri: postUri) {
            let likeUri = PostStateManager.shared.getLikeUri(postUri: postUri)
            // Viewerオブジェクトを更新（存在しない場合は作成）
            if post.viewer == nil {
                post.viewer = Viewer(repost: nil, like: likeUri, replyDisabled: nil)
            } else {
                // 既存のViewerを更新（Viewerは構造体なので新しいインスタンスを作成）
                post.viewer = Viewer(
                    repost: post.viewer?.repost,
                    like: likeUri,
                    replyDisabled: post.viewer?.replyDisabled
                )
            }
        }
        
        // 永続化されたリポスト状態を復元
        if PostStateManager.shared.isReposted(postUri: postUri) {
            let repostUri = PostStateManager.shared.getRepostUri(postUri: postUri)
            // Viewerオブジェクトを更新（存在しない場合は作成）
            if post.viewer == nil {
                post.viewer = Viewer(repost: repostUri, like: nil, replyDisabled: nil)
            } else {
                // 既存のViewerを更新
                post.viewer = Viewer(
                    repost: repostUri,
                    like: post.viewer?.like,
                    replyDisabled: post.viewer?.replyDisabled
                )
            }
        }
    }
    
    // MARK: - いいね機能
    
    /// いいね状態を取得
    var isLiked: Bool {
        return post.viewer?.like != nil
    }
    
    /// いいね処理（バッチ処理対応）
    @MainActor
    func toggleLike() async {
        guard let postUri = post.uri, let postCid = post.cid else {
            print("いいねに必要な情報（uri, cid）が不足しています")
            return
        }
        
        isLiking = true
        
        if isLiked {
            // いいね取り消しをバッチ処理に追加
            if let likeUri = post.viewer?.like {
                
                // ローカル状態を即座に更新
                post.viewer = Viewer(
                    repost: post.viewer?.repost,
                    like: nil,
                    replyDisabled: post.viewer?.replyDisabled
                )
                
                // いいね数を減らす
                if let currentCount = post.likeCount, currentCount > 0 {
                    post.likeCount = currentCount - 1
                }
                
                // 永続化状態を更新
                PostStateManager.shared.removeLiked(postUri: postUri)
                
                print("いいね取り消しをキューに追加")
            }
        } else {
            
            // ローカル状態を即座に更新（仮のURI）
            let tempLikeUri = "pending_like_\(postUri)"
            post.viewer = Viewer(
                repost: post.viewer?.repost,
                like: tempLikeUri,
                replyDisabled: post.viewer?.replyDisabled
            )
            
            // いいね数を増やす
            if let currentCount = post.likeCount {
                post.likeCount = currentCount + 1
            } else {
                post.likeCount = 1
            }
            
            // 永続化状態を更新
            PostStateManager.shared.setLiked(postUri: postUri, likeUri: tempLikeUri)
            
            print("いいねをキューに追加")
        }
        
        isLiking = false
    }
    
    // MARK: - リポスト機能
    
    /// リポスト状態を取得
    var isReposted: Bool {
        return post.viewer?.repost != nil
    }
    
    /// リポスト数を取得
    var repostCount: Int {
        return post.repostCount ?? 0
    }
    
    /// リポスト処理（バッチ処理対応）
    @MainActor
    func toggleRepost() async {
        guard let postUri = post.uri, let postCid = post.cid else {
            print("リポストに必要な情報（uri, cid）が不足しています")
            return
        }
        
        isReposting = true
        
        if isReposted {
            // リポスト取り消しをバッチ処理に追加
            if let repostUri = post.viewer?.repost {
                
                // ローカル状態を即座に更新
                post.viewer = Viewer(
                    repost: nil,
                    like: post.viewer?.like,
                    replyDisabled: post.viewer?.replyDisabled
                )
                
                // リポスト数を減らす
                if let currentCount = post.repostCount, currentCount > 0 {
                    post.repostCount = currentCount - 1
                }
                
                // 永続化状態を更新
                PostStateManager.shared.removeReposted(postUri: postUri)
                
                print("リポスト取り消しをキューに追加")
            }
        } else {
            
            // ローカル状態を即座に更新（仮のURI）
            let tempRepostUri = "pending_repost_\(postUri)"
            post.viewer = Viewer(
                repost: tempRepostUri,
                like: post.viewer?.like,
                replyDisabled: post.viewer?.replyDisabled
            )
            
            // リポスト数を増やす
            if let currentCount = post.repostCount {
                post.repostCount = currentCount + 1
            } else {
                post.repostCount = 1
            }
            
            // 永続化状態を更新
            PostStateManager.shared.setReposted(postUri: postUri, repostUri: tempRepostUri)
            
            print("リポストをキューに追加")
        }
        
        isReposting = false
    }
}
