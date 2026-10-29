import Foundation
import Testing

@testable import bskyapp

/// ローカル通知に出す対象の選び方。「選んだ種類だけ」「自分宛の返信だけ」「同じものを二度出さない」を固定する
struct LocalNotificationTests {
  private let myDid = "did:plc:me"
  private let lastSeen = "2026-10-01T12:00:00.000Z".parseToDateRemovingMilliseconds!

  private func item(
    _ reason: String, uri: String = "at://did:plc:other/app.bsky.feed.post/1",
    author: String = "did:plc:other", isRead: Bool = false,
    indexedAt: String = "2026-10-01T12:00:05.000Z", text: String? = "こんにちは",
    parentUri: String? = nil
  ) throws -> NotificationItem {
    var record: [String: Any] = [:]
    if let text { record["text"] = text }
    if let parentUri {
      record["reply"] = [
        "root": ["uri": parentUri, "cid": "c"], "parent": ["uri": parentUri, "cid": "c"],
      ]
    }
    let json: [String: Any] = [
      "uri": uri, "cid": "c", "reason": reason, "isRead": isRead, "indexedAt": indexedAt,
      "author": ["did": author, "handle": "alice.bsky.social", "displayName": "Alice"],
      "record": record,
    ]
    return try JSONDecoder().decode(
      NotificationItem.self, from: JSONSerialization.data(withJSONObject: json))
  }

  private func deliver(
    _ items: [NotificationItem], reasons: Set<NotificationReason> = Set(NotificationReason.allCases),
    alreadyNotified: Set<String> = []
  ) -> [String] {
    LocalNotificationService.notificationsToDeliver(
      items, since: lastSeen, alreadyNotified: alreadyNotified, myDid: myDid, reasons: reasons
    ).map(\.uri)
  }

  @Test func onlySelectedReasonsAreDelivered() throws {
    let mention = try item("mention", uri: "m")
    let like = try item("like", uri: "l")
    #expect(deliver([mention, like], reasons: [.mention]) == ["m"])
    #expect(deliver([mention, like], reasons: []) == [])
  }

  @Test func replyOnlyWhenParentIsMine() throws {
    let toMe = try item("reply", uri: "r1", parentUri: "at://did:plc:me/app.bsky.feed.post/a")
    let toOther = try item(
      "reply", uri: "r2", parentUri: "at://did:plc:me2/app.bsky.feed.post/a")
    #expect(deliver([toMe, toOther]) == ["r1"])
  }

  @Test func skipsOldReadOwnAndAlreadyNotified() throws {
    let old = try item("mention", uri: "old", indexedAt: "2026-10-01T11:59:59.000Z")
    let read = try item("mention", uri: "read", isRead: true)
    let own = try item("mention", uri: "own", author: myDid)
    let done = try item("mention", uri: "done")
    let fresh = try item("mention", uri: "fresh")
    #expect(deliver([old, read, own, done, fresh], alreadyNotified: ["done"]) == ["fresh"])
  }

  @Test func sameSecondAsLastSeenIsDelivered() throws {
    // indexedAt は秒単位で比べるので、基準点と同じ秒のものも出す（重複は uri で防ぐ）
    let sameSecond = try item("mention", uri: "s", indexedAt: "2026-10-01T12:00:00.500Z")
    #expect(deliver([sameSecond]) == ["s"])
  }

  @Test func mutedUsersAndWordsAreSkipped() throws {
    let muted = try item("mention", uri: "u", author: "did:plc:muted")
    let word = try item("mention", uri: "w", text: "ネタバレ注意")
    let ok = try item("mention", uri: "ok")
    let result = LocalNotificationService.notificationsToDeliver(
      [muted, word, ok], since: lastSeen, alreadyNotified: [], myDid: myDid,
      reasons: [.mention], isMutedUser: { $0 == "did:plc:muted" },
      isMutedText: { $0.contains("ネタバレ") })
    #expect(result.map(\.uri) == ["ok"])
  }

  @Test func deliveredOldestFirst() throws {
    let newer = try item("mention", uri: "b", indexedAt: "2026-10-01T12:00:09.000Z")
    let older = try item("mention", uri: "a", indexedAt: "2026-10-01T12:00:03.000Z")
    #expect(deliver([newer, older]) == ["a", "b"])
  }

  @Test func contentText() throws {
    let replyItem = try item(
      "reply", text: "ありがとう", parentUri: "at://did:plc:me/app.bsky.feed.post/a")
    let reply = LocalNotificationService.content(for: replyItem)
    #expect(reply.title == "Aliceさんが返信しました")
    #expect(reply.body == "ありがとう")

    let followItem = try item("follow", text: nil)
    let follow = LocalNotificationService.content(for: followItem)
    #expect(follow.title == "Aliceさんにフォローされました")
    #expect(follow.body == "")
  }
}
