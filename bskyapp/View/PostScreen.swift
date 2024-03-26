import SwiftUI

struct PostScreen: View {
    @StateObject var screenModel: PostScreenModel
    @State var isPostCompleted:Bool = false
    @State var isPostFailed:Bool = false
    @State var isTextValid: Bool = true
    var maxTextCount: Int = 300
    var body: some View {
        VStack{
            Text("hello world")
            TextField("つぶやきたいこと", text:$screenModel.text)
                .textFieldStyle(.roundedBorder)
                .border(isTextValid ? Color.green : Color.red)
                .onChange(of: screenModel.text) {
                    // ユーザー名のバリデーション
                    isTextValid = 0 < screenModel.text.count && screenModel.text.count <= maxTextCount
                }
            Text("\(screenModel.text.count) / \(maxTextCount)")
            if !isTextValid {
                Text(screenModel.text.count == 0 ? "何か言うことはないか": "言いたいことが多すぎる")
            }
                
            
            Button("送信") {
                Task{
                    do{
                        try await screenModel.send()
                        self.isPostCompleted = true
                        screenModel.text = ""
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
