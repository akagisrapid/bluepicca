//
//  ThreadgateList.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct ThreadgateList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: String
    let avatar: String?
    let labels: [Label]
    let viewer: Viewer?
    let indexedAt: String?
}
