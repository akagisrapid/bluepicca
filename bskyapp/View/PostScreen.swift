import SwiftUI

struct PostScreen: View {
    @StateObject var screenModel: PostScreenModel
    @State var isPostCompleted:Bool = false
    var body: some View {
        VStack{
            Text("hello world")
            TextField("つぶやきたいこと", text:$screenModel.text)
                .textFieldStyle(.roundedBorder)
            
            Button("送信") {
                Task{
                    await screenModel.send()
                    self.isPostCompleted = false
                }
            }
        }.alert(isPresented: $isPostCompleted){
            Alert(title: Text("送信完了"), message: nil)
        }
    }
}
