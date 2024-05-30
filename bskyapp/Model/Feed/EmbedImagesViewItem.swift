import Foundation

struct EmbedImagesViewItem: Codable {
    let thumb: String
    let fullsize: String
    let alt: String
    let aspectRatio: AspectRatio?
    let image: ImageItem?
}
