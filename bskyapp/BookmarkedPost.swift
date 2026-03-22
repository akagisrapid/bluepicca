import Foundation
import SwiftData

@Model
final class BookmarkedPost {
    var postUri: String
    var postCid: String
    var authorDisplayName: String
    var authorHandle: String
    var authorAvatarUrl: String?
    var text: String
    var createdAt: Date

    init(
        postUri: String,
        postCid: String,
        authorDisplayName: String,
        authorHandle: String,
        authorAvatarUrl: String?,
        text: String
    ) {
        self.postUri = postUri
        self.postCid = postCid
        self.authorDisplayName = authorDisplayName
        self.authorHandle = authorHandle
        self.authorAvatarUrl = authorAvatarUrl
        self.text = text
        self.createdAt = Date()
    }
}
