import Foundation

class FeedItem: Codable, ObservableObject, Identifiable {
    let post: Post?
    let reply: Reply?
    let reason: Reason?
    
    // 固有のIDを生成（ポストのcidとリポスト者のdidを組み合わせ）
    var id: String {
        let postId = post?.cid ?? "no-post"
        let reasonId = reason?.by.did ?? "no-reason"
        return "\(postId)-\(reasonId)"
    }
}
