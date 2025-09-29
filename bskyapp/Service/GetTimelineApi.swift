import Foundation
import Alamofire

struct GetTimelineApi{
    func getTimeline(cursor: String? = nil) async throws -> FeedResponse{
        // キャッシュをチェック（初回読み込み時のみ）
        if cursor == nil, let cachedTimeline = TimelineCacheManager.shared.getCachedTimeline() {
            print("Using cached timeline data")
            return cachedTimeline
        }
        
        print("Fetching timeline from API with cursor: \(cursor ?? "nil")")
        
        // SafeAPIExecutorを使用してレート制限対応
        let result = try await SafeAPIExecutor.shared.execute(endpoint: "timeline") {
            let session = try await SessionManager.shared.getSession()
            let endPoint = "https://bsky.social/xrpc/"
            let repo = "app.bsky.feed.getTimeline"
            let urlString = endPoint + repo
            
            let param: FeedRequest = FeedRequest(algorithm: "", limit: 50, cursor: cursor) // limit を50に削減
            let headers: HTTPHeaders =
            [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessJwt)"
            ]
            
            print("Making timeline request to: \(urlString)")
            
            let response = await AF.request(urlString, method: .get, parameters: param, headers: headers)
                .validate()
                .serializingDecodable(FeedResponse.self).response
            
            switch response.result{
            case .success(let res):
                print("Timeline API success: received \(res.feed.count) items")
                // 初回読み込み時のみキャッシュに保存
                if cursor == nil {
                    TimelineCacheManager.shared.cacheTimeline(res)
                }
                return res
            case .failure(let error):
                print("Timeline API error:")
                print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
                print("Status Code: \(response.response?.statusCode ?? 0)")
                print("Error: \(error)")
                throw error
            }
        }
        
        return result
    }
}
