import Foundation
import Alamofire
import Keys

func createSession() async throws -> CreateSessionResponse {
    // For backward compatibility, use the hardcoded values
    let identifier = "akagisrapid.bsky.social"
    let password = getBskyPasswordFromKeychain()
    
    return try await createSession(identifier: identifier, password: password)
}

func createSession(identifier: String, password: String) async throws -> CreateSessionResponse {
    let endPoint = "https://bsky.social/xrpc/"
    let createSession = "com.atproto.server.createSession"
    let urlString = endPoint + createSession
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json"
    ]
    
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
        
        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            print(response.request?.url ?? "No URL")
            print(response.response?.statusCode ?? 0)
            print(error)
            
            // Throw more specific errors based on status code
            if let statusCode = response.response?.statusCode {
                switch statusCode {
                case 401:
                    throw SessionError.invalidCredentials
                case 500...599:
                    throw SessionError.networkError
                default:
                    throw error
                }
            } else {
                throw SessionError.networkError
            }
        }
    } catch {
        if let sessionError = error as? SessionError {
            throw sessionError
        } else {
            throw SessionError.unknown
        }
    }
}
