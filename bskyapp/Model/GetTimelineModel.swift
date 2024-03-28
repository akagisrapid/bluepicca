import Foundation

// JSONからマッピングするための構造体定義
struct Author: Codable {
    let did: String
    let handle: String
    let displayName: String
    let avatar: String
    let associated: Associated
    let viewer: AuthorViewer
    let labels: [Label]
}

struct Associated: Codable {
    let lists: Int
    let feedgens: Int
    let labeler: Bool
}

struct AuthorViewer: Codable {
    let muted: Bool
    let mutedByList: MutedByList
    let blockedBy: Bool
    let blocking: String
    let blockingByList: BlockingByList
    let following: String
    let followedBy: String
}

struct Viewer: Codable {
    let repost: String
    let like: String
    let replyDisabled: Bool
}
struct MutedByList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: String
    let avatar: String
    let labels: [Label]
    let viewer: Viewer
    let indexedAt: String
}

struct BlockingByList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: String
    let avatar: String
    let labels: [Label]
    let viewer: Viewer
    let indexedAt: String
}

struct Label: Codable {
    let ver: Int
    let src: String
    let uri: String
    let cid: String
    let val: String
    let neg: Bool
    let cts: String
    let exp: String
    let sig: String
}

struct Post: Codable {
    let uri: String
    let cid: String
    let author: Author
    let record: [String: String] // JSONの"record"フィールドの値がオブジェクトであるため、[String: String]として定義
    let embed: [String: String] // JSONの"embed"フィールドの値がオブジェクトであるため、[String: String]として定義
    let replyCount: Int?
    let repostCount: Int?
    let likeCount: Int?
    let indexedAt: String
    let viewer: Viewer
    let labels: [Label]
    let threadgate: Threadgate
}

struct Threadgate: Codable {
    let uri: String
    let cid: String
    let record: [String: String] // JSONの"record"フィールドの値がオブジェクトであるため、[String: String]として定義
    let lists: [List]
}

struct List: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: String
    let avatar: String
    let labels: [Label]
    let viewer: Viewer
    let indexedAt: String
}

struct FeedResponse: Codable {
    let cursor: String
    let feed: [FeedItem]
}

struct FeedItem: Codable {
    let post: Post
    let reply: Reply
    let reason: [String: String] // JSONの"reason"フィールドの値がオブジェクトであるため、[String: String]として定義
}

struct Reply: Codable {
    let root: [String: String] // JSONの"root"フィールドの値がオブジェクトであるため、[String: String]として定義
    let parent: [String: String] // JSONの"parent"フィールドの値がオブジェクトであるため、[String: String]として定義
}
