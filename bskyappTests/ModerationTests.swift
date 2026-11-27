import Foundation
import Testing

@testable import bskyapp

/// センシティブ表示の判定。App Store 審査（ガイドライン 1.2）に関わるので、
/// 「hide が最優先」「否定ラベルは無視」「関係ないラベルでは隠さない」を固定する
@Suite(.serialized)
@MainActor  // 画面が見ている共有の設定を書き換えるので、メインスレッドで動かす
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

/// テストを走らせるアプリも起動時に Bluesky と同期して entries を書き換える。
/// 同期と同じメインスレッドで動かし、途中で書き換わらないようにする
@Suite(.serialized)
@MainActor
struct MuteWordManagerTests {
  private let manager = MuteWordManager.shared

  private func withWords(_ words: [String], _ body: () -> Void) {
    let saved = manager.entries
    let savedUpload = manager.upload
    manager.upload = { _ in }  // 本物の Bluesky アカウントに書き込まない
    manager.muteWords = words
    defer {
      manager.upload = savedUpload
      manager.entries = saved
      UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: "muteWordEntries")
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

  private func post(embed: String) throws -> Post {
    let json =
      #"{"uri": "at://did:plc:abc/app.bsky.feed.post/1", "cid": "c", "#
      + #""record": {"text": "ふつうの本文", "createdAt": "2026-10-01T00:00:00Z"}, "#
      + #""embed": "# + embed + "}"
    return try JSONDecoder().decode(Post.self, from: Data(json.utf8))
  }

  /// 本文に無くても、引用元・リンクカード・ALT にあればミュートする
  @Test func postMatchesQuoteLinkCardAndAlt() throws {
    let quote = try post(embed: #"""
      {"$type": "app.bsky.embed.record#view",
       "record": {"$type": "app.bsky.embed.record#viewRecord", "uri": "at://x/app.bsky.feed.post/2",
                  "value": {"text": "引用元のネタバレ", "createdAt": "2026-10-01T00:00:00Z"}}}
      """#)
    let link = try post(embed: #"""
      {"$type": "app.bsky.embed.external#view",
       "external": {"uri": "https://spoiler.example.com/a", "title": "記事", "description": ""}}
      """#)
    let image = try post(embed: #"""
      {"$type": "app.bsky.embed.images#view",
       "images": [{"thumb": "t", "fullsize": "f", "alt": "ネタバレ画像"}]}
      """#)
    withWords(["ネタバレ", "spoiler.example.com"]) {
      #expect(manager.matches(quote))
      #expect(manager.matches(link))
      #expect(manager.matches(image))
    }
    withWords(["関係ない語"]) {
      #expect(!manager.matches(quote))
    }
  }

  /// タグのみの語は、本文に同じ文字があってもタグに無ければミュートしない
  @Test func tagTargetMatchesOnlyHashtags() throws {
    let tagged = try post(embed: "null").withRecord(
      #"{"text": "実況 #ネタバレ", "createdAt": "2026-10-01T00:00:00Z", "#
        + #""facets": [{"index": {"byteStart": 7, "byteEnd": 20}, "#
        + #""features": [{"$type": "app.bsky.richtext.facet#tag", "tag": "ネタバレ"}]}]}"#)
    let plain = try post(embed: "null").withRecord(
      #"{"text": "ネタバレ注意", "createdAt": "2026-10-01T00:00:00Z"}"#)
    withWords([]) {
      manager.add("#ネタバレ", target: .tag)
      #expect(manager.matches(tagged))
      #expect(!manager.matches(plain))
      #expect(!manager.matches("ネタバレ注意"))
    }
  }

  /// Bluesky の mutedWord と相互に変換でき、id と actorTarget を失わない
  @Test func convertsBlueskyMutedWord() throws {
    let tagOnly = try #require(
      MutedWordsPreferenceApi.muteWord(from: [
        "id": "abc", "value": "ネタバレ", "targets": ["tag"],
        "actorTarget": "exclude-following", "expiresAt": "2026-12-01T00:00:00.000Z",
      ]))
    #expect(tagOnly.target == .tag)
    #expect(tagOnly.expiresAt == ISO8601DateFormatter().date(from: "2026-12-01T00:00:00Z"))
    let back = MutedWordsPreferenceApi.item(from: tagOnly)
    #expect(back["id"] as? String == "abc")
    #expect(back["targets"] as? [String] == ["tag"])
    #expect(back["actorTarget"] as? String == "exclude-following")
    #expect(back["expiresAt"] as? String == "2026-12-01T00:00:00.000Z")

    let content = try #require(
      MutedWordsPreferenceApi.muteWord(from: ["value": "spoiler", "targets": ["content", "tag"]]))
    #expect(content.target == .content && content.expiresAt == nil)
    #expect(MutedWordsPreferenceApi.item(from: content)["targets"] as? [String] == ["content", "tag"])
    #expect(MutedWordsPreferenceApi.item(from: content)["actorTarget"] as? String == "all")
  }

  /// 送信は語を変えた時点の送り先で行う。後から送り先を差し替えても、そちらには送らない
  /// （テストが差し替えを戻した後に本物の送信が走り、試験用の語がアカウントに書き込まれた）
  @Test func uploadUsesSenderAtTimeOfChange() async {
    let saved = manager.entries
    let savedUpload = manager.upload
    defer {
      manager.upload = savedUpload
      manager.entries = saved
      UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: "muteWordEntries")
    }
    var sentToFirst: [[String]] = []
    var sentToSecond: [[String]] = []
    manager.upload = { words in await MainActor.run { sentToFirst.append(words.map(\.value)) } }
    manager.entries = []
    manager.add("試験用の語")
    manager.upload = { words in await MainActor.run { sentToSecond.append(words.map(\.value)) } }
    try? await Task.sleep(for: .milliseconds(200))
    #expect(sentToFirst == [["試験用の語"]])
    #expect(sentToSecond.isEmpty)
  }

  /// 期限を過ぎた語は効かず、一覧の muteWords にも出ない
  @Test func expiredWordDoesNotMatch() {
    withWords([]) {
      manager.entries = [MuteWord(value: "昨日の話題", expiresAt: .now - 1)]
      #expect(!manager.matches("昨日の話題です"))
      #expect(manager.muteWords.isEmpty)
      manager.add("今日の話題", duration: 60)
      #expect(manager.matches("今日の話題です"))
    }
  }
}

@Suite(.serialized)
@MainActor  // 画面が見ている共有の設定を書き換えるので、メインスレッドで動かす
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
@MainActor  // 画面が見ている共有の設定を書き換えるので、メインスレッドで動かす
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

extension Post {
  /// テスト用に record だけ差し替えた投稿を作る
  fileprivate func withRecord(_ recordJSON: String) throws -> Post {
    let json =
      #"{"uri": "at://did:plc:abc/app.bsky.feed.post/1", "cid": "c", "record": "# + recordJSON + "}"
    return try JSONDecoder().decode(Post.self, from: Data(json.utf8))
  }
}
