import Foundation
import Alamofire

struct GetNotificationsApi {
    func getNotifications(limit: Int = 50, cursor: String? = nil) async throws -> NotificationResponse {
        print("Fetching notifications from API")
        
        let session = try await SessionManager.shared.getSession()
        let endPoint = "https://bsky.social/xrpc/"
        let repo = "app.bsky.notification.listNotifications"
        let urlString = endPoint + repo
        
        var parameters: [String: Any] = ["limit": limit]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(session.accessJwt)"
        ]
        
        print("Making notifications request to: \(urlString)")
        
        let response = await AF.request(urlString, method: .get, parameters: parameters, headers: headers)
            .validate()
            .serializingDecodable(NotificationResponse.self).response
        
        switch response.result {
        case .success(let res):
            print("Notifications API success: received \(res.notifications.count) items")
            return res
        case .failure(let error):
            print("Notifications API error:")
            print("URL: \(response.request?.url?.absoluteString ?? "unknown")")
            print("Status Code: \(response.response?.statusCode ?? 0)")
            print("Error: \(error)")
            throw error
        }
    }
}
