import Foundation

struct ImageItem: Codable {
    let type: String?
    let ref: [String]
    let mimeType: String
    let size: Int64
}
