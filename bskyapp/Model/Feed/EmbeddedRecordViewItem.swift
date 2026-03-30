import Foundation

struct EmbeddedRecordViewRecord: Codable {
    let uri: String?
    let author: Author?
    let value: PostRecord?
}

struct EmbeddedRecordViewItem: Codable {
    let record: EmbeddedRecordViewRecord?
}
