import SwiftUI

struct PostCardView: View {
    @StateObject var viewModel: PostCardViewModel
    var maxTextCount: Int = 300
    var body: some View {
        VStack{
            Text("hello world")
            TextField("つぶやきたいこと", text:$viewModel.text)
                .textFieldStyle(.roundedBorder)
                .border(viewModel.isTextValid ? Color.green : Color.red)
                .onChange(of: viewModel.text) {
                    // ユーザー名のバリデーション
                    viewModel.isTextValid = 0 < viewModel.text.count && viewModel.text.count <= maxTextCount
                }
            Text("\(viewModel.text.count) / \(maxTextCount)")
            if !viewModel.isTextValid {
                Text(viewModel.text.count == 0 ? "何か言うことはないか": "言いたいことが多すぎる")
            }
                
            
            Button("送信") {
                Task{
                    do{
                        try await viewModel.postText()
                        viewModel.isPostCompleted = true
                        viewModel.text = ""
                    }
                    catch{
                        viewModel.isPostFailed = true
                    }
                }
            }
        }.alert(isPresented: $viewModel.isPostCompleted){
            Alert(title: Text("送信完了"), message: nil)
        }
        .alert(isPresented: $viewModel.isPostFailed){
            Alert(title: Text("送信エラー"), message: nil)
        }
    }
}
