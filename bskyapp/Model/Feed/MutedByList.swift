import Foundation

struct MutedByList: Codable {
    let uri: String
    let cid: String
    let name: String
    let purpose: DefsModListItem?
    let avatar: String?
    let labels: [Label]
    let viewer: MutedByListViewer?
    let indexedAt: String
}
