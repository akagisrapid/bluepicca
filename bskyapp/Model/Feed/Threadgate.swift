import Foundation

struct Threadgate: Codable {
    let uri: String?
    let cid: String?
    let record: PostRecord?
    let lists: [ThreadgateList]
}
