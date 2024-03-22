//
//  Item.swift
//  bskyapp
//
//  Created by 名鉄開発用 on 2024/02/22.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
