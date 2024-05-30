import Foundation

struct Embed: Codable {
    let type: String?
    let images: [EmbedImagesViewItem]?
    let external: EmbeddedExternalViewItem?
    let record: EmbeddedRecordViewItem?
}
