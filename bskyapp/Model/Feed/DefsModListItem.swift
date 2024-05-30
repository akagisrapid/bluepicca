//
//  DefsModListItem.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct DefsModListItem: Codable {
    let avatar: String?
    let labels: [Label]?
    let viewer: MutedByListViewer?
    let indexedAt: String?
}
