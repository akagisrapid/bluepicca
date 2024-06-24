import Foundation

struct EmbedImagesViewItem: Codable {
    let thumb: String
    let fullsize: String
    let alt: String
    let aspectRatio: AspectRatio?
    let image: ImageItem?
}

extension EmbedImagesViewItem{
    var thumbUrl: URL?{
        URL(string: thumb)
    }
    var fullsizeUrl: URL?{
        URL(string: fullsize)
    }
}

