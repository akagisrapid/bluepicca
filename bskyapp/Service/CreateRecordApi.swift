import Foundation
import Alamofire

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
            print(response.request?.url)
            print(response.response?.statusCode)
            print(error)
            throw error
        }
    }
    catch{
        throw error
    }
}
