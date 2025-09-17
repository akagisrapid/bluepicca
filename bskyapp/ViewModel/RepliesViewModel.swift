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
    
    // リプライのみをフィルタリング
    var replyNotifications: [NotificationItem] {
        return notifications.filter { $0.reason == "reply" }
    }
    
    init() {
        // 初期化時は自動でフェッチしない（ビューが表示されるときにフェッチ）
    }
    
    @MainActor
    func fetchReplies() async {
        do {
            self.isFetchingReplies = true
            let repliesResponse = try await GetRepliesApi().getReplies()
            self.notifications = repliesResponse.notifications
            self.isFetchingReplies = false
        } catch {
            self.isFetchingReplies = false
            print("Error fetching replies: \(error)")
        }
    }
}
