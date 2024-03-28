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
//    var vm : PostScreenViewModel = PostScreenViewModel(text: "samp")
//    ContentView(postScreenVm: vm)
//}
