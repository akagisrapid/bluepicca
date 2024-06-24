import Foundation

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    init(post: Post) {
        self.post = post
    }
}
