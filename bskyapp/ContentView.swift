import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    var timelineScreenVm: TimelineScreenModel
    @State var isFetchTimelineFailed:Bool = false
    
    var body: some View {
        NavigationStack {
            VStack{
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
                        Spacer()
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
#Preview {
    ContentView(timelineScreenVm: TimelineScreenModel(feeds: []))
}
