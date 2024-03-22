import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    var postScreenVm : PostScreenModel
    
    var body: some View {
        NavigationStack {
            VStack{
                PostScreen(screenModel: postScreenVm)
            }
        }
        
    }
}
//#Preview {
//    var vm : PostScreenViewModel = PostScreenViewModel(text: "samp")
//    ContentView(postScreenVm: vm)
//}
