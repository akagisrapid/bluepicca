import Foundation

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    
    init(post: Post) {
        self.post = post
    }
    var avatarUrl: URL?{
        guard let avatar = post.author.avatar else{
            return nil
        }
        return URL(string: avatar)
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
