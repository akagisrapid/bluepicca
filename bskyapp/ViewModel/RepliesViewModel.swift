//
//  RepliesViewModel.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation

class RepliesViewModel: ObservableObject {
  @Published var notifications: [NotificationItem] = []
  @Published var isFetchingReplies: Bool = false
  private let notificationsApi = GetNotificationsApi()
  private var myDid: String?

  // リプライのみをフィルタリング（自分宛のもののみ）
  var replyNotifications: [NotificationItem] {
    return notifications.filter { notification in
      // リプライかつ、自分宛のもののみを表示
      return notification.reason == "reply" && isReplyToMe(notification)
    }
  }

  init() {
    // 初期化時は自動でフェッチしない（ビューが表示されるときにフェッチ）
  }

  @MainActor
  func fetchReplies() async {
    isFetchingReplies = true

    do {
      // セッション情報を取得して自分のDIDを保存
      let session = try await SessionManager.shared.getSession()
      self.myDid = session.did

      let response = try await notificationsApi.getNotifications()
      self.notifications = response.notifications
      dlog(
        "Fetched \(response.notifications.count) notifications, \(replyNotifications.count) replies to me"
      )
    } catch {
      dlog("Error fetching replies: \(error)")
    }

    isFetchingReplies = false
  }

  // 自分宛のリプライかどうかを判定
  private func isReplyToMe(_ notification: NotificationItem) -> Bool {
    guard let myDid = self.myDid else {
      return false
    }

    // リプライの場合、record.reply.parent.uriに返信先の情報が含まれている
    // または、通知の対象が自分の投稿への返信かどうかを確認
    if let record = notification.record,
      let reply = record.reply,
      let parent = reply.parent,
      let parentUri = parent.uri
    {
      // 返信先の投稿のURIから、自分の投稿への返信かどうかを判定
      // URIの形式: at://did:plc:xxx/app.bsky.feed.post/xxx
      return parentUri.contains(myDid)
    }

    return false
  }
}
