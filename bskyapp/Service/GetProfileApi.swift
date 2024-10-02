import Foundation
import Alamofire

struct GetProfileApi{
    func getProfile(param: GetProfileApiRequest) async throws -> GetProfileApiResponse{
        let session = try await createSession()
        let endPoint = "https://bsky.social/xrpc/"
        let repo = "app.bsky.actor.getProfile"
        let urlString = endPoint + repo
        
        let headers: HTTPHeaders =
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
                .validate()
                .serializingDecodable(GetProfileApiResponse.self).response
            switch response.result{
            case .success(let res):
                return res
            case .failure(let error):
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
}
