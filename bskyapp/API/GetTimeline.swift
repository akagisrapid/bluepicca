import Foundation

func getTimeline() async throws -> FeedResponse{
    let session = try await createSession()
    let endPoint = "https://bsky.social/xrpc/"
    let repo = "app.bsky.feed.getTimeline"
    let urlString = endPoint + repo
    
    var req = URLRequest(url: URL(string: urlString)!)
    req.httpMethod = "GET"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else{
        print(response)
        throw URLError(.badServerResponse)
    }
    guard let json = try JSONDecoder().decode(FeedResponse?.self, from: data) else{
        print("error")
        throw URLError(.badServerResponse)
    }
    print(json.feed)
    return json
}
