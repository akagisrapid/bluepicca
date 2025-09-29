import Foundation
import Alamofire

struct GetRepliesApi {
    func getReplies() async throws -> NotificationResponse {
        // キャッシュをチェック
        if let cachedNotifications = RepliesCacheManager.shared.getCachedNotifications() {
            print("Using cached notifications data")
            return cachedNotifications
        }
        
        // SafeAPIExecutorを使用してレート制限対応
        return try await SafeAPIExecutor.shared.execute(endpoint: "replies") {
            let session = try await SessionManager.shared.getSession()
            let endPoint = "https://bsky.social/xrpc/"
            let repo = "app.bsky.notification.listNotifications"
            let urlString = endPoint + repo
            
            let headers: HTTPHeaders = [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessJwt)"
            ]
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let response = await AF.request(urlString, method: .get, headers: headers)
                    .validate()
                    .serializingDecodable(NotificationResponse.self).response
                
                switch response.result {
                case .success(let res):
                    // キャッシュに保存
                    RepliesCacheManager.shared.cacheNotifications(res)
                    return res
                case .failure(let error):
                    print(response.request?.url)
                    print(response.response?.statusCode)
                    print(error)
                    throw error
                }
            } catch {
                throw error
            }
        }
    }
}
