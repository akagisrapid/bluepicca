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
        post.record?.text ?? ""
    }
    
    var textWithLinks: AttributedString {
        text.detectLinks()
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
