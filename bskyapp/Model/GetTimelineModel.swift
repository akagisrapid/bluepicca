import Foundation

// MARK: - Author

struct Author: Codable {
    let did: String
    let handle: String
    let displayName: String
    let avatar: String
    let associated: Associated?
    let viewer: AuthorViewer?
    let labels: [Label]
}

// MARK: - Associated

struct Associated: Codable {
    let lists: Int?
    let feedgens: Int?
    let labeler: Bool?
}

// MARK: - AuthorViewer

struct AuthorViewer: Codable {
    let muted: Bool
    let mutedByList: MutedByList?
    let blockedBy: Bool
    let blocking: String?
    let blockingByList: BlockingByList?
    let following: String?
    let followedBy: String?
}

// MARK: - Viewer

struct Viewer: Codable {
    let repost: String?
    let like: String?
    let replyDisabled: Bool?
}

// MARK: - MutedByList

struct MutedByList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: DefsModListItem?
    let avatar: String
    let labels: [Label]
    let viewer: MutedByListViewer?
    let indexedAt: String
}

// MARK: - MutedByListViewer

struct MutedByListViewer: Codable {
    let muted: Bool
    let blocked: String
}

// MARK: - BlockingByList

struct BlockingByList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: DefsModListItem
    let avatar: String
    let labels: [Label]
    let viewer: MutedByListViewer?
    let indexedAt: Date?
}

// MARK: - Label

struct Label: Codable {
    let ver: Int?
    let src: String
    let uri: String
    let cid: String?
    let val: String
    let neg: Bool?
    let cts: String?
    let exp: Date?
    let sig: UInt8?
}

// MARK: - Post

struct Post: Codable {
    let uri: String
    let cid: String
    let author: Author
    let record: PostRecord
    let embed: Embed?
    let replyCount: Int?
    let repostCount: Int?
    let likeCount: Int?
    let indexedAt: String
    let viewer: Viewer
    let labels: [Label]
    let threadgate: Threadgate?
}

// MARK: - PostRecord

struct PostRecord: Codable {
    let type: String?
    let createdAt: String?
    let langs: [String]?
    let text: String?
}

// MARK: - Embed

struct Embed: Codable {
    let type: String?
    let images: [EmbedImagesViewItem]?
    let external: EmbeddedExternalViewItem?
    let record: EmbeddedRecordViewItem?
}

// MARK: - EmbeddedExternalViewItem

struct EmbeddedExternalViewItem: Codable {
    let uri: String
    let title: String
    let description: String
    let thumb: String?
}

// MARK: - EmbeddedRecordViewItem

struct EmbeddedRecordViewItem: Codable {
    let record: PostRecord?
}

// MARK: - Threadgate

struct Threadgate: Codable {
    let uri: String?
    let cid: String?
    let record: PostRecord?
    let lists: [ThreadgateList]
}

// MARK: - List

struct ThreadgateList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: [String: String]
    let avatar: String?
    let labels: [Label]
    let viewer: Viewer?
    let indexedAt: Date?
}

// MARK: - FeedRequest

struct FeedRequest: Codable {
    let algorithm: String?
    let limit: Int?
    let cursor: String?
}

// MARK: - FeedResponse

struct FeedResponse: Codable {
    let cursor: String?
    let feed: [FeedItem]
}

// MARK: - FeedItem

struct FeedItem: Codable {
    let post: Post
    let reply: Reply?
    let reason: Reason?
}

// MARK: - Reply

struct Reply: Codable {
    let root: Post
    let parent: Post
}

// MARK: - Reason

struct Reason: Codable {
    let by: Author
    let indexedAt: String
}

// MARK: - EmbedImagesViewItem

struct EmbedImagesViewItem: Codable {
    let thumb: String
    let fullsize: String
    let alt: String
    let aspectRatio: AspectRatio?
    let image: ImageItem?
}

// MARK: - AspectRatio

struct AspectRatio: Codable {
    let height: Int
    let width: Int
}

// MARK: - ImageItem

struct ImageItem: Codable {
    let type: String?
    let ref: [String]
    let mimeType: String
    let size: Int64
}

// MARK: - DefsModListItem

struct DefsModListItem: Codable {
    let avatar: String?
    let labels: [Label]?
    let viewer: MutedByListViewer?
    let indexedAt: String?
}

