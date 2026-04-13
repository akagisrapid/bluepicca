import Foundation

struct DeleteRecordRequest: Codable {
    let repo: String
    let collection: String
    let rkey: String
    let swapRecord: String?
    let swapCommit: String?
}

struct DeleteRecordResponse: Codable {
    // 削除APIのレスポンスは通常空なので、Codableに準拠するだけで十分
}
