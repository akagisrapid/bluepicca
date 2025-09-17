import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var viewModel: ContentViewModel
    @State private var isShowReplies = false
    
    var body: some View {
        NavigationStack {
            VStack{
                Text("timelines")
                if viewModel.isFetchingTimeline{
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2.0) // サイズを調整したい場合
                        .padding()
                } else {
                    List(viewModel.validFeeds) { feedItem in
                        if let post = feedItem.post {
                            var timelineCardViewModel = TimelineCardViewModel(post: post, reason: feedItem.reason)
                            var postDetailViewModel = PostDetailViewModel(post: post)
                            NavigationLink(
                                destination: PostDetailView(viewModel: postDetailViewModel)
                            ){
                                TimelineCardView(
                                    viewModel: timelineCardViewModel)
                            }
                        }
                    }.listStyle(.plain)
                }
            }
            
            
            .sheet(isPresented: $viewModel.isShowPostCard){
                ZStack{
                    PostCardView(
                        viewModel: PostCardViewModel(text: ""),isShowPostCard: $viewModel.isShowPostCard)
                    .padding()
                    .background(.clear) // PostCardViewの背景色
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding()
                    .transition(.scale)
                }
            }
        }
        
        .toolbar{
            ToolbarItem(placement: .bottomBar){
                HStack{
                    Button("Post", systemImage: "square.and.pencil"){
                        withAnimation (.easeInOut(duration: 0.3)){
                            viewModel.isShowPostCard.toggle()
                        }
                    }
                    Button("Replies", systemImage: "bubble.left.and.bubble.right"){
                        isShowReplies = true
                    }
                    Spacer()
                    Button("Refresh", systemImage: "arrow.clockwise"){
                        Task {
                            do {
                                try await viewModel.fetchTimeline()
                            } catch {
                                print("Error fetching timeline: \(error)")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowReplies) {
            RepliesView(viewModel: RepliesViewModel())
        }
    }
}
#Preview {
    var vm = ContentViewModel()
    return ContentView(viewModel: vm)
}
