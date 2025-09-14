import Foundation

class PostDetailViewModel: ObservableObject{
    @Published var post: Post
    var likesResponse: GetLikesApiResponse = .init(uri: "", likes: [])
    
    init(post: Post) {
        self.post = post
        Task{
            self.likesResponse = try await GetLikesApi().getLikes(param: .init(uri: post.uri,cid: post.cid))
        }
        print(likesResponse)
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
    var embeddedImages : [EmbedImagesViewItem]{
        guard let images = post.embed?.images else{
            return []
        }
        return images
    }
}
