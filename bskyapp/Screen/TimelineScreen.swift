import SwiftUI

struct TimelineScreen: View {
    @StateObject var viewModel: TimelineViewModel = TimelineViewModel()
    @StateObject var screenModel: TimelineScreenModel = TimelineScreenModel(feeds: [])
    @State var isFetchTimelineFailed:Bool = false
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
            if screenModel.isFetchingTimeline{
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2.0) // サイズを調整したい場合
                    .padding()
            }else{
                List(screenModel.feeds, id: \.post.cid) { post in
                    TimelineCardView(feed: post)
                }
            }
        }
        
        .alert(isPresented: $isFetchTimelineFailed){
            Alert(title: Text("タイムラインの受信に失敗しました"), message: nil)
        }
    }
}

class TimelineViewModel: ObservableObject{
    @Published var isShowButton: Bool = false
}
