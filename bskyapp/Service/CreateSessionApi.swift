import Foundation

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
    return try await HTTPClient.decode(
      CreateSessionResponse.self, urlString, method: .post, json: param, headers: headers)
  } catch let error as HTTPError {
    dlog(error)
    // Throw more specific errors based on status code
    switch error.statusCode {
    case 401:
      throw SessionError.invalidCredentials
    case 500...599:
      throw SessionError.networkError
    default:
      throw SessionError.unknown
    }
  } catch is URLError {
    // 応答が返らなかった（圏外・タイムアウトなど）
    throw SessionError.networkError
  } catch {
    // 応答は返ったがデコードできなかった
    throw SessionError.unknown
  }
}
