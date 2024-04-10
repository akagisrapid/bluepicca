import SwiftUI

struct TimelineScreen: View {
    @StateObject var viewModel: TimelineViewModel = TimelineViewModel()
    @StateObject var screenModel: TimelineScreenModel = TimelineScreenModel(feeds: [])
    
    var body: some View {
        VStack{
            Text("timelines")
            Button("読み込む") {
                Task {
                    do {
                        try await screenModel.fetchTimeline()
                    } catch {
                        print("Error fetching timeline: \(error)")
                    }
                }
            }
            List(screenModel.feeds, id: \.post.cid) { post in
                Text("\(post.post.record.text)")
            }
        }
    }
}

class TimelineViewModel: ObservableObject{
    @Published var isShowButton: Bool = false
}
//
//#Preview {
//    TimelineScreen()
//}
