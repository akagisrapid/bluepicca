import Foundation
struct PostRecord: Codable {
    let type: String?
    let createdAt: String?
    let langs: [String]?
    let text: String?
    let facets: [Facet]?
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
}
