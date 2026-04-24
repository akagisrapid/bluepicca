import Foundation

/// app.bsky.embed.recordWithMedia#view の media フィールド
struct EmbedMedia: Codable {
    let images: [EmbedImagesViewItem]?
    let external: EmbeddedExternalViewItem?
}

struct Embed: Codable {
    let type: String?
    let images: [EmbedImagesViewItem]?
    let external: EmbeddedExternalViewItem?
    /// 引用ポスト（app.bsky.embed.record#view および recordWithMedia#view の両方に対応）
    let record: EmbeddedRecordViewItem?
    /// app.bsky.embed.recordWithMedia#view の media フィールド（画像または外部リンク）
    let media: EmbedMedia?

    // Video embed fields (top-level when $type is app.bsky.embed.video#view)
    let cid: String?
    let playlist: String?
    let thumbnail: String?
    let alt: String?
    let aspectRatio: AspectRatio?

    private enum CodingKeys: String, CodingKey {
        case type, images, external, record, media, cid, playlist, thumbnail, alt, aspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        images = try container.decodeIfPresent([EmbedImagesViewItem].self, forKey: .images)
        external = try container.decodeIfPresent(EmbeddedExternalViewItem.self, forKey: .external)
        let decodedMedia = try container.decodeIfPresent(EmbedMedia.self, forKey: .media)
        media = decodedMedia
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        playlist = try container.decodeIfPresent(String.self, forKey: .playlist)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        aspectRatio = try container.decodeIfPresent(AspectRatio.self, forKey: .aspectRatio)

        // app.bsky.embed.recordWithMedia#view の場合、record キーの値は
        // { "$type": "app.bsky.embed.record#view", "record": { 実際のデータ } } という構造になる。
        // media キーが存在すれば recordWithMedia と判断し、ネストされた record を取り出す。
        if decodedMedia != nil {
            struct RecordWrapper: Decodable {
                let record: EmbeddedRecordViewItem?
            }
            let wrapper = try container.decodeIfPresent(RecordWrapper.self, forKey: .record)
            record = wrapper?.record
        } else {
            record = try container.decodeIfPresent(EmbeddedRecordViewItem.self, forKey: .record)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(external, forKey: .external)
        try container.encodeIfPresent(record, forKey: .record)
        try container.encodeIfPresent(media, forKey: .media)
        try container.encodeIfPresent(cid, forKey: .cid)
        try container.encodeIfPresent(playlist, forKey: .playlist)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encodeIfPresent(alt, forKey: .alt)
        try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
    }
}

extension Embed {
    /// 画像（直接埋め込みまたは recordWithMedia の media.images）
    var resolvedImages: [EmbedImagesViewItem]? {
        return images ?? media?.images
    }

    /// 外部リンク（直接埋め込みまたは recordWithMedia の media.external）
    var resolvedExternal: EmbeddedExternalViewItem? {
        return external ?? media?.external
    }

    var video: EmbedVideoViewItem? {
        guard playlist != nil else { return nil }
        return EmbedVideoViewItem(
            cid: cid,
            playlist: playlist,
            thumbnail: thumbnail,
            alt: alt,
            aspectRatio: aspectRatio
        )
    }
}
