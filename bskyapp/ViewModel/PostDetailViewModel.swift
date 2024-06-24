import Foundation

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    
    init(post: Post) {
        self.post = post
    }
    var avatarUrl: URL?{
        post.author.avatarUrl
    }
    var displayName : String{
        post.author.displayName
    }
    var text: String{
        post.record.text ?? ""
    }
    var indexedAt: String{
        guard let date =  post.indexedAt.parseToDateRemovingMilliseconds else{
            return ""
        }
        return date.formatted(.dateTime)
    }
}
