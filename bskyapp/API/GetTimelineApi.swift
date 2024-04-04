import Foundation
import Alamofire

struct GetTimelineApi{
    func getTimeline() async throws -> FeedResponse{
        let session = try await createSession()
        let endPoint = "https://bsky.social/xrpc/"
        let repo = "app.bsky.feed.getTimeline"
        let urlString = endPoint + repo
        
        let param: FeedRequest = FeedRequest(algorithm: "", limit: 100, cursor: nil)
        let headers: HTTPHeaders =
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let response = try await AF.request(urlString, method: .get, parameters: param, headers: headers)
                .validate()
                .serializingDecodable(FeedResponse.self).response
            switch response.result{
            case .success(let res):
                return res
            case .failure(let error):
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
