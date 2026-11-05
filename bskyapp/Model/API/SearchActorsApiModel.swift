import Foundation

struct SearchActorsRequest: Codable {
  let q: String
  let limit: Int?
  let cursor: String?
}

struct SearchActorsResponse: Codable {
  let cursor: String?
  let actors: [ActorSearchItem]
}

/// app.bsky.actor.defs#profileView のうち、検索結果の行に使う項目
struct ActorSearchItem: Codable {
  let did: String
  let handle: String
  let displayName: String?
  let avatar: String?
  let description: String?
  let viewer: AuthorViewer?
}
