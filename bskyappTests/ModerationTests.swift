import Foundation
import Testing

@testable import bskyapp

/// センシティブ表示の判定。App Store 審査（ガイドライン 1.2）に関わるので、
/// 「hide が最優先」「否定ラベルは無視」「関係ないラベルでは隠さない」を固定する
@Suite(.serialized)
struct ContentLabelManagerTests {
  private let manager = ContentLabelManager.shared

  private func withPolicies(
    sexual: LabelPolicy, nudity: LabelPolicy = .blur, graphic: LabelPolicy = .blur,
    _ body: () -> Void
  ) {
    let saved = (manager.sexualPolicy, manager.nudityPolicy, manager.graphicPolicy)
    manager.sexualPolicy = sexual
    manager.nudityPolicy = nudity
    manager.graphicPolicy = graphic
    defer {
      manager.sexualPolicy = saved.0
      manager.nudityPolicy = saved.1
      manager.graphicPolicy = saved.2
    }
    body()
  }

  private func post(_ labels: [Label]?) -> Post {
    Post(uri: "u", cid: nil, author: nil, record: nil, labels: labels)
  }

  @Test func unlabeledPostIsShown() {
    withPolicies(sexual: .hide) {
      #expect(manager.policy(for: post(nil)) == .show)
      #expect(manager.policy(for: post([])) == .show)
      #expect(manager.policy(for: post([label("unrelated")])) == .show)
    }
  }

  @Test func eachCategoryUsesItsOwnPolicy() {
    withPolicies(sexual: .hide, nudity: .blur, graphic: .blur) {
      #expect(manager.policy(for: post([label("porn")])) == .hide)
      #expect(manager.policy(for: post([label("nsfw")])) == .hide)
      #expect(manager.policy(for: post([label("nudity")])) == .blur)
      #expect(manager.policy(for: post([label("graphic-media")])) == .blur)
    }
  }

  @Test func hideWinsOverBlur() {
    withPolicies(sexual: .blur, nudity: .hide) {
      #expect(manager.policy(for: post([label("porn"), label("nudity")])) == .hide)
    }
  }

  @Test func negatedLabelIsIgnored() {
    withPolicies(sexual: .hide) {
      #expect(manager.policy(for: post([label("porn", neg: true)])) == .show)
    }
  }
}

@Suite(.serialized)
struct MuteWordManagerTests {
  private let manager = MuteWordManager.shared

  private func withWords(_ words: [String], _ body: () -> Void) {
    let saved = manager.muteWords
    manager.muteWords = words
    defer {
      manager.muteWords = saved
      UserDefaults.standard.set(saved, forKey: "muteWords")
    }
    body()
  }

  @Test func addTrimsAndIgnoresEmptyAndDuplicates() {
    withWords([]) {
      manager.add("  ネタバレ ")
      manager.add("ネタバレ")
      manager.add("   ")
      #expect(manager.muteWords == ["ネタバレ"])
    }
  }

  @Test func matchesIsCaseInsensitiveSubstring() {
    withWords(["Spoiler", "ネタバレ"]) {
      #expect(manager.matches("big SPOILER ahead"))
      #expect(manager.matches("これはネタバレです"))
      #expect(!manager.matches("nothing here"))
    }
  }
}

@Suite(.serialized)
struct MutedUsersManagerTests {
  private let manager = MutedUsersManager.shared

  /// サーバーの正規リストで上書きし、通信失敗で残った「幽霊ミュート」を消す
  @Test func reconcileReplacesLocalOverlay() {
    let saved = manager.mutedDIDs
    defer { manager.reconcile(withServerMutedDIDs: saved) }
    manager.add(did: "did:plc:ghost")
    #expect(manager.isMuted("did:plc:ghost"))
    manager.reconcile(withServerMutedDIDs: ["did:plc:real"])
    #expect(!manager.isMuted("did:plc:ghost"))
    #expect(manager.isMuted("did:plc:real"))
  }
}

@Suite(.serialized)
struct PostStateManagerTests {
  private let manager = PostStateManager.shared
  private let uri = "at://did:plc:test/app.bsky.feed.post/state-test"

  @Test func likeAndRepostRoundTrip() {
    defer {
      manager.removeLiked(postUri: uri)
      manager.removeReposted(postUri: uri)
    }
    manager.setLiked(postUri: uri, likeUri: "like-1")
    manager.setReposted(postUri: uri, repostUri: "repost-1")
    #expect(manager.isLiked(postUri: uri))
    #expect(manager.getLikeUri(postUri: uri) == "like-1")
    #expect(manager.getRepostUri(postUri: uri) == "repost-1")

    manager.removeLiked(postUri: uri)
    #expect(!manager.isLiked(postUri: uri))
    #expect(manager.isReposted(postUri: uri))
  }
}
