//
//  NotificationResponse.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation

struct NotificationResponse: Codable {
    let cursor: String?
    let notifications: [NotificationItem]
}

struct NotificationItem: Codable, Identifiable {
    let id = UUID()
    let uri: String
    let cid: String
    let author: Author
    let reason: String
    let record: NotificationRecord?
    let isRead: Bool
    let indexedAt: String
    let labels: [Label]?
    
    private enum CodingKeys: String, CodingKey {
        case uri, cid, author, reason, record, isRead, indexedAt, labels
    }
    var indexedAtDate: Date?{
        guard let date = indexedAt.parseToDateRemovingMilliseconds else{
            return nil
        }
        return date
    }
}

struct NotificationRecord: Codable {
    let type: String?
    let text: String?
    let createdAt: String?
    let reply: Reply?
}
