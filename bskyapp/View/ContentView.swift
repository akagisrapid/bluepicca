import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationStack {
            VStack{
            Text("timelines")
                if viewModel.isFetchingTimeline{
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2.0) // サイズを調整したい場合
                    .padding()
            }else{
                List(viewModel.posts, id: \.cid) { post in
                    var timelineCardViewModel = TimelineCardViewModel(post: post)
                    TimelineCardView(
                        viewModel: timelineCardViewModel)
                }
            }
        }
        
            .toolbar{
                ToolbarItem(placement: .bottomBar){
                    HStack{
                        Button("Refresh", systemImage: "arrow.clockwise"){
                            Task {
                                do {
                                    try await viewModel.fetchTimeline()
                                } catch {
                                    print("Error fetching timeline: \(error)")
                                }
                            }
                        }
                        Spacer()
                        NavigationLink(destination:
                                        PostCardView(
                                            viewModel: PostCardViewModel(text: "")
                                        )
                        ){
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
        }
    }
}
#Preview {
    var vm = ContentViewModel()
    return ContentView(viewModel: vm)
}
