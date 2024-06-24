import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationStack {
            ZStack{
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
                            var postDetailViewModel = PostDetailViewModel(post: post)
                            NavigationLink(destination: PostDetailView(viewModel: postDetailViewModel)){
                                TimelineCardView(
                                    viewModel: timelineCardViewModel)
                            }
                        }
                    }
                }
                if viewModel.isShowPostCard{
                    ZStack {
                        Color.black.opacity(0.4) // 背景を半透明に
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.isShowPostCard = false
                                }
                            }
                        
                        PostCardView(viewModel: PostCardViewModel(text: ""),isShowPostCard: $viewModel.isShowPostCard)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding()
                            .transition(.scale)
                            .onDisappear{
                                viewModel.isShowPostCard = false
                            }
                    }
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
                    Button("Post", systemImage: "square.and.pencil"){
                        withAnimation (.easeInOut(duration: 0.3)){
                            viewModel.isShowPostCard.toggle()
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
