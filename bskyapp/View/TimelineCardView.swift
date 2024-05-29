import SwiftUI

struct TimelineCardView: View {
    @StateObject var feed: FeedItem
    var body: some View {
        VStack{
            Text(feed.authorText).font(.headline)
            Text(feed.timelineText).frame(alignment: .leading)
            Text(feed.postTimeDiffText).dynamicTypeSize(.xSmall)
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
