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

    do {
      let res = try await HTTPClient.decode(
        NotificationResponse.self, urlString, query: parameters, headers: headers)
      dlog("Notifications API success: received \(res.notifications.count) items")
      return res
    } catch {
      dlog("Notifications API error: \(error)")
      throw error
    }
  }
}
