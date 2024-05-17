import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    var postScreenVm : PostScreenModel
    var timelineScreenVm: TimelineScreenModel
    @State var isFetchTimelineFailed:Bool = false
    
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
                                    self.isFetchTimelineFailed = true
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
        .alert(isPresented: $isFetchTimelineFailed){
            Alert(title: Text("タイムラインの受信に失敗しました"), message: nil)
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
