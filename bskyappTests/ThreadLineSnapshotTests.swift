import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import bskyapp

/// 縦線の見た目を確かめるため、シミュレーター上で TL のカードを画像にする（確認用・一時的）。
/// 環境変数 SNAPSHOT_DIR があればそこへ PNG を書き出す
@MainActor
struct ThreadLineSnapshotTests {
  private func item(
    uri: String, name: String, text: String, parent: (uri: String, name: String, text: String)? = nil,
    repostedBy: String? = nil
  ) throws -> FeedItem {
    func post(_ uri: String, _ name: String, _ text: String) -> String {
      #"{"uri": "\#(uri)", "cid": "cid-\#(uri)", "author": {"did": "did:plc:\#(name)", "handle": "\#(name).bsky.social", "displayName": "\#(name)"}, "record": {"text": "\#(text)", "createdAt": "2026-11-10T09:00:00.000Z"}, "replyCount": 1, "repostCount": 2, "likeCount": 3}"#
    }
    var json = #"{"post": \#(post(uri, name, text))"#
    if let parent {
      let p = post(parent.uri, parent.name, parent.text)
      json += #", "reply": {"root": \#(p), "parent": \#(p)}"#
    }
    if let repostedBy {
      json +=
        #", "reason": {"by": {"did": "did:plc:\#(repostedBy)", "handle": "\#(repostedBy).bsky.social", "displayName": "\#(repostedBy)"}}"#
    }
    json += "}"
    return try JSONDecoder().decode(FeedItem.self, from: Data(json.utf8))
  }

  /// ContentView と同じく、隣どうしの関係から縦線のフラグを決めてカードを並べる
  private func timeline(_ items: [FeedItem]) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        let above = index > 0 ? items[index - 1] : nil
        let below = index + 1 < items.count ? items[index + 1] : nil
        TimelineCardView(
          viewModel: TimelineCardViewModel(
            post: item.post!, reason: item.reason, reply: item.reply,
            connectsToCardAbove: above.map {
              TimelineCardViewModel.isThreadConnected(above: $0, below: item)
            } ?? false,
            connectsToCardBelow: below.map {
              TimelineCardViewModel.isThreadConnected(above: item, below: $0)
            } ?? false))
        Divider()
      }
    }
    .frame(width: 393)
    .background(Color(.systemBackground))
  }

  private func render(_ name: String, _ items: [FeedItem]) throws {
    let container = try ModelContainer(
      for: BookmarkedPost.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let renderer = ImageRenderer(
      content: timeline(items).modelContainer(container))
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 393, height: nil)
    let data = try #require(renderer.uiImage?.pngData())
    guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
  }

  @Test func repostedParentAboveReply() throws {
    try render(
      "1-reposted-parent-above-reply",
      [
        try item(uri: "p", name: "alice", text: "あとからリポストされた投稿", repostedBy: "carol"),
        try item(
          uri: "r", name: "bob", text: "その投稿への返信",
          parent: ("p", "alice", "あとからリポストされた投稿")),
        try item(uri: "x", name: "dave", text: "関係のない投稿"),
      ])
  }

  @Test func parentAboveRepostedReply() throws {
    try render(
      "2-parent-above-reposted-reply",
      [
        try item(uri: "p", name: "alice", text: "元の投稿"),
        try item(
          uri: "r", name: "bob", text: "リポストされた返信",
          parent: ("p", "alice", "元の投稿"), repostedBy: "carol"),
        try item(uri: "x", name: "dave", text: "関係のない投稿"),
      ])
  }

  @Test func threeInARow() throws {
    try render(
      "3-three-in-a-row",
      [
        try item(uri: "a", name: "alice", text: "1 つ目", repostedBy: "carol"),
        try item(uri: "b", name: "alice", text: "2 つ目", parent: ("a", "alice", "1 つ目")),
        try item(uri: "c", name: "alice", text: "3 つ目", parent: ("b", "alice", "2 つ目")),
      ])
  }

  @Test func unconnectedReplyShowsPreview() throws {
    try render(
      "4-unconnected-reply",
      [
        try item(uri: "x", name: "dave", text: "関係のない投稿"),
        try item(
          uri: "r", name: "bob", text: "離れた投稿への返信", parent: ("p", "alice", "どこか別の投稿")),
      ])
  }
}
