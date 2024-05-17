import SwiftUI

struct TimelineCardScreen: View {
    @StateObject var screenModel: TimelineCardScreenModel
    var body: some View {
        VStack{
            Text(screenModel.feed.authorText).dynamicTypeSize(.xSmall)
            Text(screenModel.feed.timelineText).frame(alignment: .leading)
        }
    }
}

#Preview {
    var feed = FeedItem(
        post:
            Post(uri: "",
                 cid: "",
                 author:
                    Author(
                        did: "",
                        handle: "",
                        displayName: "aaaaa", avatar: "", associated: nil,viewer: nil,labels: []),
                 record: PostRecord(type: nil, createdAt: nil, langs: nil, text: "tezz"), embed: nil, replyCount: nil, repostCount: nil, likeCount: nil, indexedAt: "", viewer: Viewer(repost: nil, like: nil, replyDisabled: nil), labels: [], threadgate: nil), reply: nil, reason: nil)
    
    var tl = TimelineCardScreenModel(feed: feed)
    return TimelineCardScreen(screenModel: tl)
}
