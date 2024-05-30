import SwiftUI

struct TimelineCardView: View {
    @StateObject var viewModel: TimelineCardViewModel
    var body: some View {
        VStack{
            Text(viewModel.authorName).font(.headline)
            Text(viewModel.text).frame(alignment: .leading)
            Text(viewModel.postedTimeRelative).dynamicTypeSize(.xSmall)
        }
    }
}

//#Preview {
//    TimelineCardScreen(feed: FeedItem(
//        post: Post(uri: "",
//                 cid: "",
//                 author:
//                    Author(
//                        did: "",
//                        handle: "",
//                        displayName: "aaaaa",
//                        avatar: "",
//                        associated: nil,
//                        viewer: nil,
//                        labels: []
//                    ),
//                 record:
//                    PostRecord(
//                        type: nil,
//                        createdAt: nil,
//                        langs: nil,
//                        text: "tezz"
//                    ),
//                 embed: nil,
//                 replyCount: nil,
//                 repostCount: nil,
//                 likeCount: nil,
//                 indexedAt: "",
//                 viewer: Viewer(repost: nil, like: nil, replyDisabled: nil),
//                 labels: [],
//                   threadgate: nil),
//            reply: nil,
//            reason: nil
//            ))
//}
