//
//  AuthorViewer.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct AuthorViewer: Codable {
    let muted: Bool
    let mutedByList: MutedByList?
    let blockedBy: Bool
    let blocking: String?
    let blockingByList: BlockingByList?
    let following: String?
    let followedBy: String?
}
