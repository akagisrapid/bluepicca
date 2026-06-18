import Foundation

class HashtagFeedManager: ObservableObject {
  static let shared = HashtagFeedManager()
  private let key = "savedHashtagFeeds"

  @Published private(set) var hashtags: [String]

  private init() {
    hashtags = UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  func add(_ tag: String) {
    guard !hashtags.contains(tag) else { return }
    hashtags.append(tag)
    UserDefaults.standard.set(hashtags, forKey: key)
  }

  func remove(_ tag: String) {
    hashtags.removeAll { $0 == tag }
    UserDefaults.standard.set(hashtags, forKey: key)
  }

  func contains(_ tag: String) -> Bool {
    hashtags.contains(tag)
  }

  var feedTabs: [FeedTab] {
    hashtags.map { FeedTab.forHashtag($0) }
  }
}
