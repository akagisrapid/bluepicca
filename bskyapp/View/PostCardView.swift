import SwiftUI

struct PostCardView: View {
    @StateObject var viewModel: PostCardViewModel
    @Binding var isShowPostCard: Bool
    
    var body: some View {
        VStack{
            HStack{
                TextEditor(text: $viewModel.text)
                    .frame(height: 200)
                    .border(viewModel.isTextValid ? Color.green : Color.red)
                    .onChange(of: viewModel.text) {
                        viewModel.checkTextCount()
                    };
                VStack{
                    Text(viewModel.textCountString).frame(width:50)
                }
            }
            HStack{
                Spacer()
                Button(
                    "ポスト",
                    systemImage: "text.bubble.fill"){
                    Task{
                        do{
                            try await viewModel.postText()
                            viewModel.isPostCompleted = true
                            viewModel.text = ""
                            withAnimation{
                                isShowPostCard = false
                            }
                        }
                        catch{
                            viewModel.isPostFailed = true
                        }
                    }
                    }.disabled(!viewModel.isTextValid)
            }
        }.alert(isPresented: $viewModel.isPostCompleted){
            Alert(title: Text("送信完了"), message: nil)
        }
        .alert(isPresented: $viewModel.isPostFailed){
            Alert(title: Text("送信エラー"), message: nil)
        }
    }
}
