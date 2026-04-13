//
//  Label.swift
//  bskyapp
//
//  Created by shuya on 2024/05/29.
//

import Foundation
struct Label: Codable {
    let ver: Int?
    let src: String
    let uri: String
    let cid: String?
    let val: String
    let neg: Bool?
    let cts: String?
    let exp: String?
    let sig: UInt8?
}
