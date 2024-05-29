import SwiftUI

struct PostView: View {
    @StateObject var viewModel: PostCardViewModel
    @State var isPostCompleted:Bool = false
    @State var isPostFailed:Bool = false
    @State var isTextValid: Bool = true
    var maxTextCount: Int = 300
    var body: some View {
        VStack{
            Text("hello world")
            TextField("つぶやきたいこと", text:$viewModel.text)
                .textFieldStyle(.roundedBorder)
                .border(isTextValid ? Color.green : Color.red)
                .onChange(of: viewModel.text) {
                    // ユーザー名のバリデーション
                    isTextValid = 0 < viewModel.text.count && viewModel.text.count <= maxTextCount
                }
            Text("\(viewModel.text.count) / \(maxTextCount)")
            if !isTextValid {
                Text(viewModel.text.count == 0 ? "何か言うことはないか": "言いたいことが多すぎる")
            }
                
            
            Button("送信") {
                Task{
                    do{
                        try await viewModel.postText()
                        self.isPostCompleted = true
                        viewModel.text = ""
                    }
                    catch{
                        self.isPostFailed = true
                    }
                }
            }
        }.alert(isPresented: $isPostCompleted){
            Alert(title: Text("送信完了"), message: nil)
        }
        .alert(isPresented: $isPostFailed){
            Alert(title: Text("送信エラー"), message: nil)
        }
    }
}
