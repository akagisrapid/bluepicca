//
//  FeedResponse.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct FeedResponse: Codable {
    let cursor: String?
    let feed: [FeedItem]
}
