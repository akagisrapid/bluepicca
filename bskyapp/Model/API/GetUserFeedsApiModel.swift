import Foundation

// MARK: - getPreferences

struct GetPreferencesResponse: Codable {
    let preferences: [PreferenceItem]
}

struct PreferenceItem: Codable {
    // savedFeedsPrefV2 の items フィールドのみ取り出す。
    // $type 等の他フィールドは無視。
    let items: [SavedFeedItem]?
}

struct SavedFeedItem: Codable {
    let type: String   // "feed" | "list" | "timeline"
    let value: String  // AT URI (feed/list) or "following" (timeline)
    let pinned: Bool
    let id: String
}

// MARK: - getFeedGenerators

struct GetFeedGeneratorsResponse: Codable {
    let feeds: [FeedGeneratorView]
}

struct FeedGeneratorView: Codable {
    let uri: String
    let displayName: String
    let description: String?
    let avatar: String?
}

// MARK: - FeedTab（UI用）

struct FeedTab: Identifiable {
    let id: String
    let name: String
    let uri: String?      // nil = ホームTL（getTimeline）、non-nil = getFeed
    let avatarUrl: URL?

    static let home = FeedTab(id: "home", name: "ホーム", uri: nil, avatarUrl: nil)
}
