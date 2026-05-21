import Alamofire
import Foundation

struct GetNotificationsApi {
  func getNotifications(limit: Int = 50, cursor: String? = nil) async throws -> NotificationResponse
  {
    dlog("Fetching notifications from API")

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
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    dlog("Making notifications request to: \(urlString)")

    let response = await AF.request(
      urlString, method: .get, parameters: parameters, headers: headers
    )
    .validate()
    .serializingDecodable(NotificationResponse.self).response

    switch response.result {
    case .success(let res):
      dlog("Notifications API success: received \(res.notifications.count) items")
      return res
    case .failure(let error):
      dlog("Notifications API error:")
      dlog("URL: \(response.request?.url?.absoluteString ?? "unknown")")
      dlog("Status Code: \(response.response?.statusCode ?? 0)")
      dlog("Error: \(error)")
      throw error
    }
  }
}
