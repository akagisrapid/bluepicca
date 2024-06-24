import Foundation
    

class PostCardViewModel:  ObservableObject {
    @Published var text: String = ""
    @Published var isPostCompleted:Bool = false
    @Published var isPostFailed:Bool = false
    @Published var isTextValid: Bool = false
    
    var maxTextCount: Int = 300
    
    init(text: String){
        self.text = text
    }
    
    func postText() async throws {
        do{
            let param = try await makeCreateRecordRequest(text: text)
            try await createRecord(param: param)
        }
    }
    func checkTextCount(){
        isTextValid = 0 < text.count && text.count <= maxTextCount
    }
    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }
}
