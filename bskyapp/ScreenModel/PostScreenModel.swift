import Foundation

class PostScreenModel: ObservableObject {
    @Published var text: String = ""
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
