import Foundation
import SwiftUI

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    var likesResponse: GetLikesApiResponse = .init(uri: "", likes: [])
    
    init(post: Post) {
        self.post = post
        Task{
            // uriやcidがnilの場合でも問題なく動作するようにする
            if let uri = post.uri {
                self.likesResponse = try await GetLikesApi().getLikes(param: .init(uri: uri, cid: post.cid))
            }
        }
        print(likesResponse)
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
        return date.formatted(.dateTime)
    }
    var embeddedImages : [EmbedImagesViewItem]{
        guard let images = post.embed?.images else{
            return []
        }
        return images
    }
}
