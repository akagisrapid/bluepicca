import Foundation
struct PostRecord: Codable {
    let type: String?
    let createdAt: String?
    let langs: [String]?
    let text: String?
    let facets: [Facet]?
    /// 本文に出さないハッシュタグ（app.bsky.feed.post の tags）
    let tags: [String]?
}

class Facet: Codable {
    let index: FacetIndex?
    let features: [FacetFeature]?
}

class FacetIndex: Codable {
    let byteStart: Int
    let byteEnd: Int
}

class FacetFeature: Codable {
    let type: String?
    let uri: String?
    /// app.bsky.richtext.facet#tag のタグ（# なし）
    let tag: String?
}
