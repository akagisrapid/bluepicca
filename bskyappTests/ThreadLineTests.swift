import Foundation
import Testing

@testable import bskyapp

/// TL のスレッドの字下げ。上のカードが下のカードの直接の返信先ならつなぎ、
/// リポストが混ざっても切らない
struct ThreadLineTests {
  private func item(uri: String, parent: String? = nil, repostedBy: String? = nil) throws
    -> FeedItem
  {
    var json = #"{"post": {"uri": "\#(uri)", "cid": "cid-\#(uri)"}"#
    if let parent {
      json += #", "reply": {"root": {"uri": "\#(parent)"}, "parent": {"uri": "\#(parent)"}}"#
    }
    if let repostedBy {
      json += #", "reason": {"by": {"did": "\#(repostedBy)", "handle": "x.bsky.social"}}"#
    }
    json += "}"
    return try JSONDecoder().decode(FeedItem.self, from: Data(json.utf8))
  }

  @Test func connectsParentToDirectReply() throws {
    let parent = try item(uri: "p")
    let reply = try item(uri: "r", parent: "p")
    #expect(TimelineCardViewModel.isThreadConnected(above: parent, below: reply))
  }

  @Test func doesNotConnectUnrelatedOrReversedPosts() throws {
    let parent = try item(uri: "p")
    let reply = try item(uri: "r", parent: "p")
    let other = try item(uri: "o", parent: "x")
    #expect(!TimelineCardViewModel.isThreadConnected(above: reply, below: parent))
    #expect(!TimelineCardViewModel.isThreadConnected(above: parent, below: other))
    #expect(!TimelineCardViewModel.isThreadConnected(above: parent, below: parent))
  }

  @Test func repostedParentStillConnects() throws {
    let repostedParent = try item(uri: "p", repostedBy: "did:plc:x")
    let reply = try item(uri: "r", parent: "p")
    #expect(TimelineCardViewModel.isThreadConnected(above: repostedParent, below: reply))
  }

  @Test func repostedReplyStillConnects() throws {
    let parent = try item(uri: "p")
    let repostedReply = try item(uri: "r", parent: "p", repostedBy: "did:plc:x")
    #expect(TimelineCardViewModel.isThreadConnected(above: parent, below: repostedReply))
  }
}
