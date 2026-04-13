//
//  FeedRequest.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct FeedRequest: Codable {
    let algorithm: String?
    let limit: Int?
    let cursor: String?
}
