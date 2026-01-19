import Foundation

struct GetActorLikesRequest: Codable {
    let actor: String
    let limit: Int?
    let cursor: String?
}
