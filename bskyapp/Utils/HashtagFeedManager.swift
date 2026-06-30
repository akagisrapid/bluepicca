import Foundation

class HashtagFeedManager: ObservableObject {
  static let shared = HashtagFeedManager()
  private let localKey = "savedHashtagFeeds"

  @Published private(set) var hashtags: [String]

  private init() {
    hashtags = UserDefaults.standard.stringArray(forKey: localKey) ?? []
    Task { await syncFromServer() }
  }

  func add(_ tag: String) {
    guard !hashtags.contains(tag) else { return }
    hashtags.append(tag)
    saveLocal()
    Task { try? await HashtagPreferenceApi().putHashtags(hashtags) }
  }

  func remove(_ tag: String) {
    hashtags.removeAll { $0 == tag }
    saveLocal()
    Task { try? await HashtagPreferenceApi().putHashtags(hashtags) }
  }

  func contains(_ tag: String) -> Bool {
    hashtags.contains(tag)
  }

  var feedTabs: [FeedTab] {
    hashtags.map { FeedTab.forHashtag($0) }
  }

  private func saveLocal() {
    UserDefaults.standard.set(hashtags, forKey: localKey)
  }

  @MainActor
  private func syncFromServer() async {
    guard let serverHashtags = try? await HashtagPreferenceApi().getHashtags() else { return }
    hashtags = serverHashtags
    saveLocal()
  }
}
