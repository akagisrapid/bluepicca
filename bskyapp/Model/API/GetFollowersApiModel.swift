import Foundation

struct GetFollowersApiRequest: Codable {
    var actor: String
    var limit: Int?
    var cursor: String?
}

struct GetFollowersApiResponse: Codable {
    var subject: FollowerSubject
    var cursor: String?
    var followers: [FollowerItem]
}

struct FollowerSubject: Codable {
    var did: String
    var handle: String
    var displayName: String?
    var avatar: String?
    var associated: Associated?
    var viewer: AuthorViewer?
    var labels: [Label]
    var createdAt: String?
}

struct FollowerItem: Codable {
    var did: String
    var handle: String
    var displayName: String?
    var avatar: String?
    var associated: Associated?
    var viewer: AuthorViewer?
    var labels: [Label]
    var createdAt: String?
}
