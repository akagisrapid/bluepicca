import Foundation

struct EmbedVideoViewItem: Codable {
    let cid: String?
    let playlist: String?
    let thumbnail: String?
    let alt: String?
    let aspectRatio: AspectRatio?
}

extension EmbedVideoViewItem {
    var thumbnailUrl: URL? {
        guard let thumbnail = thumbnail else {
            return nil
        }
        return URL(string: thumbnail)
    }

    var playlistUrl: URL? {
        guard let playlist = playlist else {
            return nil
        }
        return URL(string: playlist)
    }
}
