import Foundation
struct GetProfileApiRequest: Codable {
        var actor: String
}

struct GetProfileApiResponse: Codable {
    var did: String
    var handle: String
    var displayName: String?
    var description: String?
    var avatar: String?
    var banner: String?
    var followersCount: Int?
    var followsCount: Int?
    var postsCount: Int?
    var associated: Associated?
    var indexedAt: String?
    var createdAt: String?
    var viewer: AuthorViewer?
    var labels: [Label]
    var pronouns: String?
    /// プロフィールに並べるリンク（表示順）。取り下げられたものは AppView が除いて返す
    var links: [ProfileLinkView]?
}

struct ProfileLinkView: Codable, Hashable {
    var url: String
    var title: String?
    var icon: String?
}

extension GetProfileApiResponse{
    var indexedAtDate: Date?{
        guard let date = indexedAt?.parseToDateRemovingMilliseconds else{
            return nil
        }
        return date
    }
    var createdAtDate: Date?{
        guard let date = createdAt?.parseToDateRemovingMilliseconds else{
            return nil
        }
        return date
    }
}
