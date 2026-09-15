import Foundation

struct CreateReportSubject: Encodable {
  let type: String
  let uri: String
  let cid: String

  private enum CodingKeys: String, CodingKey {
    case type = "$type"
    case uri, cid
  }
}

struct CreateReportRequest: Encodable {
  let reasonType: String
  let reason: String?
  let subject: CreateReportSubject
}

struct CreateReportResponse: Decodable {
  let id: Int
}
