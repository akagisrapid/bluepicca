import Foundation
    

class PostCardViewModel:  ObservableObject {
    @Published var text: String = ""
    @Published var isPostCompleted:Bool = false
    @Published var isPostFailed:Bool = false
    @Published var isTextValid: Bool = true
    init(text: String){
        self.text = text
    }
    
    func postText() async throws {
        do{
            let param = try await makeCreateRecordRequest(text: text)
            try await createRecord(param: param)
        }
    }
}
