import Foundation

struct GetFollowsApiRequest: Codable {
    var actor: String
    var limit: Int?
    var cursor: String?
}

struct GetFollowsApiResponse: Codable {
    var subject: FollowSubject
    var cursor: String?
    var follows: [FollowItem]
}

struct FollowSubject: Codable {
    var did: String
    var handle: String
    var displayName: String?
    var avatar: String?
    var associated: Associated?
    var viewer: AuthorViewer?
    var labels: [Label]
    var createdAt: String?
}

struct FollowItem: Codable {
    var did: String
    var handle: String
    var displayName: String?
    var avatar: String?
    var associated: Associated?
    var viewer: AuthorViewer?
    var labels: [Label]
    var createdAt: String?
}
