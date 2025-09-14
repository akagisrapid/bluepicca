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
            // Update UI properties on the main thread
            await MainActor.run {
                errorMessage = error.localizedDescription
                if let afError = error as? Alamofire.AFError, 
                   let statusCode = afError.responseCode,
                   statusCode == 429 {
                    errorMessage = "投稿回数制限に達しました。しばらく待ってから再度お試しください。"
                    // Clear session to force a new one next time
                    SessionManager.shared.clearSession()
                }
            }
            throw error
        }
    }
    func checkTextCount(){
        // Ensure we're on the main thread when updating published properties
        DispatchQueue.main.async {
            self.isTextValid = 0 < self.text.count && self.text.count <= self.maxTextCount
        }
    }
    var textCountString: String {
        "\(text.count) / \(maxTextCount)"
    }
}
