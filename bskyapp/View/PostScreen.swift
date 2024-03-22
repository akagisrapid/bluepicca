import SwiftUI

struct PostScreen: View {
    @StateObject var screenModel: PostScreenModel
    @State var isPostCompleted:Bool = false
    @State var isPostFailed:Bool = false
    var body: some View {
        VStack{
            Text("hello world")
            TextField("つぶやきたいこと", text:$screenModel.text)
                .textFieldStyle(.roundedBorder)
            
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
