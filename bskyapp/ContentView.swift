import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    var postScreenVm : PostScreenModel
    var timelineScreenVm: TimelineScreenModel
    
    var body: some View {
        NavigationStack {
            VStack{
                PostScreen(screenModel: postScreenVm)
                TimelineScreen(screenModel: timelineScreenVm)
            }
            .toolbar{
                ToolbarItem(placement: .bottomBar){
                    HStack{
                        Button("Refresh", systemImage: "arrow.clockwise"){
                            Task {
                                do {
                                    try await timelineScreenVm.fetchTimeline()
                                } catch {
                                    print("Error fetching timeline: \(error)")
                                }
                            }
                        }
                        Button("Post", systemImage: "rectangle.and.pencil.and.ellipsis"){
                            
                        }
                    }
                }
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
