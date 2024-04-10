import Foundation
import Alamofire

struct PostItem{
    let text: String
    let postDate: Date
}
//func createRecord(postItem: PostItem) async throws -> CreateRecordResponse{
//    let endPoint = "https://bsky.social/xrpc/"
//    let createRecord = "com.atproto.repo.createRecord"
//    
//    let session = try await createSession()
//    
//    let httpMethod = HttpMethodType.post
//    let urlString = endPoint + createRecord
//    
//    var req = URLRequest(url: URL(string: urlString)!)
//    req.httpMethod = "POST"
//    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
//    req.addValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
//    req.httpBody = try JSONEncoder().encode(
//        CreateRecordRequest(did: session.did, text: postItem.text, createdAt: postItem.postDate)
//    )
//    let (data, response) = try await URLSession.shared.data(for: req)
//    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else{
//        print(response)
//        throw URLError(.badServerResponse)
//    }
//    let d =  try JSONDecoder().decode(CreateRecordResponse.self, from: data)
//    print(d)
//    return d
//}


func createRecord(param: CreateRecordRequest) async throws -> CreateRecordResponse{
    let endPoint = "https://bsky.social/xrpc/"
    let createRecord = "com.atproto.repo.createRecord"
    
    let session = try await createSession()
    let urlString = endPoint + createRecord
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(session.accessJwt)"
        ]
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    do {
        let response = await AF.request(
                urlString,
                method: .post, 
                parameters: param,
                encoder: JSONParameterEncoder.default,
                headers: headers)
            .validate()
            .serializingDecodable(CreateRecordResponse.self)
            .response
        
        switch response.result{
        case .success(let value):
            return value
        case.failure(let error):
            print(response.response?.statusCode)
            print(error)
            throw error
        }
    }
    catch{
        throw error
    }
}
