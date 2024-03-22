import Foundation

struct CreateSessionRequest: Codable {
    let identifier: String
    let password: String
}

struct CreateSessionResponse: Codable{
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
    let email: String?
}

func createSession(identifier: String, password: String) async throws -> CreateSessionResponse{
    let endPoint = "https://bsky.social/xrpc/"
    let createSession = "com.atproto.server.createSession"
    let urlString = endPoint + createSession
    
    var req = URLRequest(url: URL(string: urlString)!)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode(CreateSessionRequest(identifier: identifier, password: password))
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
        print(response)
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(CreateSessionResponse.self, from: data)
}
