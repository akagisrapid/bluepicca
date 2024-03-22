import Foundation

class PostScreenModel: ObservableObject {
    @Published var text: String
    init(text: String){
        self.text = text
    }

    func send() async throws{
        do{
            let postItem = PostItem(text: text, postDate: Date())
            try await postText(postItem: postItem)
        }
    }
    
    func postText(postItem: PostItem) async throws{
        do{
            let identifier = "akagisrapid.bsky.social"
            let password = "qYmf0eXep-_Q8Iw" // とりあえず決め打ち
            let session = try await createSession(identifier: identifier, password: password)
            try await createRecord(session: session, postItem: postItem)
        }
    }
    

    
    func makeURLRequest(
        httpMethod: HttpMethodType,
        urlString: String,
        isAuth: Bool,
        accessToken: String? = nil
    ) async throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw SystemError.failure("Failed to parse url.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if isAuth == true, let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
}
