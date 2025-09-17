import Foundation

class TimelineCardViewModel: ObservableObject{
    @Published var post: Post
    @Published var reason: Reason?
    
    init(post: Post, reason: Reason? = nil) {
        self.post = post
        self.reason = reason
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
}
