import Foundation

class TimelineCardViewModel: ObservableObject{
    @Published var post: Post
    init(post: Post) {
        self.post = post
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
}
