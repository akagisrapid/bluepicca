import SwiftUI

struct TimelineScreen: View {
    @StateObject var screenModel: TimelineScreenModel
    
    var body: some View {
        VStack{
            Text("timelines")
            Button("読み込む"){
                Task{
                    do{
                        try await screenModel.fetchTimeline()
                    }
                }
            }
            ForEach(screenModel.timeline.feed, id: \.post.cid) {post in
                Text("\(post.post.author)")
            }
        }
    }
}
//
//#Preview {
//    TimelineScreen()
//}
