//
//  Author.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation
struct Author: Codable {
    let did: String
    let handle: String
    let displayName: String
    let avatar: String?
    let associated: Associated?
    let viewer: AuthorViewer?
    let labels: [Label]
}
