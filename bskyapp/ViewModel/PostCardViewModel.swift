import Foundation
import Alamofire
    

class PostCardViewModel:  ObservableObject {
    @Published var text: String = ""
    @Published var isPostCompleted:Bool = false
    @Published var isPostFailed:Bool = false
    @Published var isTextValid: Bool = false
    @Published var errorMessage: String = ""
    
    var maxTextCount: Int = 300
    
    init(text: String){
        self.text = text
    }
    
    func postText() async throws {
        do{
            let param = try await makeCreateRecordRequest(text: text)
            try await createRecord(param: param)
        } catch {
            errorMessage = error.localizedDescription
            if let afError = error as? Alamofire.AFError, 
               let statusCode = afError.responseCode,
               statusCode == 429 {
                errorMessage = "投稿回数制限に達しました。しばらく待ってから再度お試しください。"
                // Clear session to force a new one next time
                SessionManager.shared.clearSession()
            }
            throw error
        }
    }
    func checkTextCount(){
        isTextValid = 0 < text.count && text.count <= maxTextCount
    }
    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }
}
