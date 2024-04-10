import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    var postScreenVm : PostScreenModel
    var timelineScreenVm: TimelineScreenModel
    
    var body: some View {
        NavigationStack {
            VStack{
                PostScreen(screenModel: postScreenVm)
                TimelineScreen(screenModel: timelineScreenVm)
            }
        }
        
    }
}
//#Preview {
//    var vm = PostScreenModel(text: "samp")
//    var feeds = [
////            FeedItem(post: <#T##Post#>, reply: nil, reason: nil)
//    ]
//    var timeLineVm = TimelineScreenModel(feeds: [])
//    ContentView(postScreenVm: vm, timelineScreenVm: timeLineVm)
//}
