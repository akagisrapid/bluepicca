import Foundation
import SwiftUI

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    @Published var reason: Reason?
    @Published var isReposting: Bool = false
    @Published var isLiking: Bool = false
    @Published var replies: [ThreadViewPost] = []
    @Published var isFetchingReplies: Bool = false
    var likesResponse: GetLikesApiResponse = .init(uri: "", likes: [])
    
    init(post: Post, reason: Reason? = nil) {
        self.post = post
        self.reason = reason
        
        // 永続化された状態を復元
        restorePersistedStates()
        Task{
            // uriやcidがnilの場合でも問題なく動作するようにする
            if let uri = post.uri {
                    do {
                        let response = try await GetLikesApi().getLikes(param: .init(uri: uri, cid: post.cid))
                        
                        await MainActor.run {
                            self.likesResponse = response
                        }
                    } catch {
                        print("Failed to fetch likes: \(error)")
                    }
                
                
                // リプライを取得
                await fetchReplies()
            }
        }
    }
    var avatarUrl: URL?{
        post.author?.avatarUrl
    }
    var displayName : String{
        post.author?.displayName ?? ""
    }
    var text: String{
        return post.record?.text ?? ""
    }
    
    var textWithLinks: AttributedString {
        let uri = post.record?.facets?.first?.features?.first?.uri
        return uri?.detectLinks() ?? AttributedString(text)
    }
    
    var externalLink: EmbeddedExternalViewItem? {
        return post.embed?.external
    }
    
    var hasExternalLink: Bool {
        return externalLink != nil
    }
    
    // すべてのリンクからEmbeddedExternalViewItemを生成
    var linkCards: [EmbeddedExternalViewItem] {
        var cards: [EmbeddedExternalViewItem] = []
        
        // 投稿に含まれる外部リンク情報があれば追加
        if let external = post.embed?.external {
            cards.append(external)
        }
        
        // facetsからURIを取得して外部リンク情報を生成
        if let facets = post.record?.facets {
            for facet in facets {
                if let features = facet.features {
                    for feature in features {
                        if let uri = feature.uri, !uri.isEmpty {
                            // 既に追加済みのURIは重複して追加しない
                            let alreadyExists = cards.contains { $0.uri == uri }
                            if !alreadyExists {
                                // URIからEmbeddedExternalViewItemを生成
                                let externalItem = createExternalViewItem(from: uri)
                                cards.append(externalItem)
                            }
                        }
                    }
                }
            }
        }
        
        return cards
    }
    
    // URIからEmbeddedExternalViewItemを生成するヘルパーメソッド
    private func createExternalViewItem(from uri: String) -> EmbeddedExternalViewItem {
        // URIからホスト名を抽出
        var title = uri
        if let url = URL(string: uri), let host = url.host {
            title = host
        }
        
        // 実際のアプリでは、ここでAPIを呼び出してリンク先のメタデータを取得する
        // このサンプルではダミーデータを返す
        return EmbeddedExternalViewItem(
            uri: uri,
            title: title,
            description: "リンク先のコンテンツ",
            thumb: nil
        )
    }
    var indexedAt: String{
        guard let indexedAt = post.indexedAt, let date = indexedAt.parseToDateRemovingMilliseconds else{
            return ""
        }
        return date.formatted(.dateTime.hour().minute())
    }
    var embeddedImages : [EmbedImagesViewItem]{
        guard let images = post.embed?.images else{
            return []
        }
        return images
    }
    
    // リポスト機能
    @MainActor
    func repost() async {
        guard let uri = post.uri, let cid = post.cid else {
            print("リポストに必要な情報（uri, cid）が不足しています")
            return
        }
        
        isReposting = true
        
        do {
            let response = try await createRepost(postUri: uri, postCid: cid)
            print("リポスト成功: \(response)")
            
            // リポスト数を更新
            if let currentCount = post.repostCount {
                post.repostCount = currentCount + 1
            } else {
                post.repostCount = 1
            }
            
        } catch {
            print("リポストエラー: \(error)")
        }
        
        isReposting = false
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
    
    /// いいね数を取得
    var likeCount: Int {
        return post.likeCount ?? 0
    }
    
    /// いいね処理
    @MainActor
    func toggleLike() async {
        guard let postUri = post.uri, let postCid = post.cid else {
            print("いいねに必要な情報（uri, cid）が不足しています")
            return
        }
        
        isLiking = true
        
        do {
            if isLiked {
                // いいね取り消し
                if let likeUri = post.viewer?.like {
                    try await deleteLike(likeUri: likeUri)
                    
                    // ローカル状態を更新
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
                    
                    print("いいね取り消し成功")
                }
            } else {
                // いいね追加
                let response = try await createLike(postUri: postUri, postCid: postCid)
                
                // ローカル状態を更新
                post.viewer = Viewer(
                    repost: post.viewer?.repost,
                    like: response.uri,
                    replyDisabled: post.viewer?.replyDisabled
                )
                
                // いいね数を増やす
                if let currentCount = post.likeCount {
                    post.likeCount = currentCount + 1
                } else {
                    post.likeCount = 1
                }
                
                // 永続化状態を更新
                PostStateManager.shared.setLiked(postUri: postUri, likeUri: response.uri)
                
                print("いいね成功: \(response)")
            }
        } catch {
            print("いいねエラー: \(error)")
        }
        
        isLiking = false
    }
    
    // MARK: - リポスト機能の更新
    
    /// リポスト状態を取得
    var isReposted: Bool {
        return post.viewer?.repost != nil
    }
    
    /// リポスト数を取得
    var repostCount: Int {
        return post.repostCount ?? 0
    }
    
    /// リポスト処理（既存のrepost関数を置き換え）
    @MainActor
    func toggleRepost() async {
        guard let postUri = post.uri, let postCid = post.cid else {
            print("リポストに必要な情報（uri, cid）が不足しています")
            return
        }
        
        isReposting = true
        
        do {
            if isReposted {
                // リポスト取り消し
                if let repostUri = post.viewer?.repost {
                    try await deleteRepost(repostUri: repostUri)
                    
                    // ローカル状態を更新
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
                    
                    print("リポスト取り消し成功")
                }
            } else {
                // リポスト追加
                let response = try await createRepost(postUri: postUri, postCid: postCid)
                
                // ローカル状態を更新
                post.viewer = Viewer(
                    repost: response.uri,
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
                PostStateManager.shared.setReposted(postUri: postUri, repostUri: response.uri)
                
                print("リポスト成功: \(response)")
            }
        } catch {
            print("リポストエラー: \(error)")
        }
        
        isReposting = false
    }
    
    // MARK: - リプライ機能
    
    /// リプライを取得（キャッシュ対応）
    @MainActor
    func fetchReplies() async {
        guard let postUri = post.uri else {
            print("リプライ取得に必要な情報（uri）が不足しています")
            return
        }
        
        isFetchingReplies = true
        
        do {
            let response =
                try await GetPostThreadApi().getPostThread(uri: postUri)
            
            replies = response.thread.replies ?? []
            
            
            print("リプライ取得成功: \(replies.count)件")
        } catch {
            print("リプライ取得エラー: \(error)")
        }
        
        isFetchingReplies = false
    }
}
