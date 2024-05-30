import Foundation
import Alamofire
import Keys

func createSession() async throws -> CreateSessionResponse{
    let identifier = "akagisrapid.bsky.social"
    
    let endPoint = "https://bsky.social/xrpc/"
    let createSession = "com.atproto.server.createSession"
    let urlString = endPoint + createSession
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json"
        ]
    
    let password = getBskyPasswordFromKeychain()
    
    let param: CreateSessionRequest = CreateSessionRequest(identifier: identifier, password: password)
    
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
            .serializingDecodable(CreateSessionResponse.self)
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
