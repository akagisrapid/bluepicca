import Foundation
import SwiftUI

struct Author: Codable {
  let did: String
  let handle: String?
  let displayName: String?
  let avatar: String?
  let associated: Associated?
  let viewer: AuthorViewer?
  let labels: [Label]?
}

extension Author {
  var avatarUrl: URL? {
    guard let avatar = avatar else {
      return nil
    }
    return URL(string: avatar)
  }
}
