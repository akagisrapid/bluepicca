import Foundation
import Alamofire

func getTimeline() async throws -> FeedResponse{
    let session = try await createSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getTimeline"
    let urlString = endPoint + repo
    
    let param: FeedRequest = FeedRequest(algorithm: "", limit: 20, cursor: "")
    let headers = HTTPHeaders(
        []
        )
    
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    var res = FeedResponse(cursor: "", feed: [])
    AF.request(urlString,method: .get,parameters: param, headers: headers)
        .responseDecodable(of: FeedResponse.self, decoder: decoder) { response in
            print(response.value)
           print( response.response?.statusCode)
            guard let result = response.value else{
                return
            }
            res = result
        }
    return res
}

//
//    
//    var req = URLRequest(url: URL(string: urlString)!)
//    req.httpMethod = "GET"
//    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
//    req.addValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
//    let (data, response) = try await URLSession.shared.data(for: req)
//    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else{
//        print(response)
//        throw URLError(.badServerResponse)
//    }
//    guard let json = try JSONDecoder().decode(FeedResponse?.self, from: data) else{
//        print("error")
//        throw URLError(.badServerResponse)
//    }
//    print(json.feed)
//    return json

