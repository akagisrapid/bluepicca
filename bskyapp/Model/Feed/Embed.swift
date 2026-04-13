import Foundation

struct Embed: Codable {
    let type: String?
    let images: [EmbedImagesViewItem]?
    let external: EmbeddedExternalViewItem?
    let record: EmbeddedRecordViewItem?

    // Video embed fields (top-level when $type is app.bsky.embed.video#view)
    let cid: String?
    let playlist: String?
    let thumbnail: String?
    let alt: String?
    let aspectRatio: AspectRatio?
}

extension Embed {
    var video: EmbedVideoViewItem? {
        guard playlist != nil else {
            return nil
        }
        return EmbedVideoViewItem(
            cid: cid,
            playlist: playlist,
            thumbnail: thumbnail,
            alt: alt,
            aspectRatio: aspectRatio
        )
    }
}
