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
    // sig（署名）は仕様上 {"$bytes": "..."} のオブジェクトで届くが使わないので持たない。
    // 以前の UInt8? 宣言では、sig 付きのラベルが来るとその投稿を含むフィードごとデコードに失敗する
}
