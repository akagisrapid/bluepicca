import Foundation
import Testing

@testable import bskyapp

/// API の JSON をそのまま受けるモデル。1 か所でもデコードに失敗するとフィードごと読めなくなるので、
/// 実際の応答の形（`$type` キー、入れ子の record、blob の ref.$link）で固定する
struct ModelDecodingTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }

  private let postJSON = #"""
    {
      "uri": "at://did:plc:abc/app.bsky.feed.post/3k",
      "cid": "bafyreia",
      "author": {"did": "did:plc:abc", "handle": "alice.bsky.social", "displayName": "Alice"},
      "record": {
        "$type": "app.bsky.feed.post",
        "createdAt": "2026-10-01T12:34:56.789Z",
        "text": "こんにちは https://example.com",
        "facets": [{
          "index": {"byteStart": 16, "byteEnd": 35},
          "features": [{"$type": "app.bsky.richtext.facet#link", "uri": "https://example.com"}]
        }]
      },
      "replyCount": 1, "repostCount": 2, "likeCount": 3,
      "indexedAt": "2026-10-01T12:34:57.000Z",
      "viewer": {"like": "at://did:plc:me/app.bsky.feed.like/1"},
      "labels": [
        {"src": "did:plc:mod", "uri": "at://did:plc:abc/app.bsky.feed.post/3k", "val": "porn",
         "cts": "2026-10-01T12:35:00.000Z", "ver": 1, "sig": {"$bytes": "c2lnbmF0dXJl"}}
      ]
    }
    """#

  @Test func postDecodesCountsViewerAndFacets() throws {
    let post = try decode(Post.self, postJSON)
    #expect(post.uri == "at://did:plc:abc/app.bsky.feed.post/3k")
    #expect(post.author?.handle == "alice.bsky.social")
    #expect(post.likeCount == 3)
    #expect(post.viewer?.like == "at://did:plc:me/app.bsky.feed.like/1")
    let facet = try #require(post.record?.facets?.first)
    #expect(facet.index?.byteStart == 16)
    #expect(facet.features?.first?.uri == "https://example.com")
  }

  /// ファセットの位置は UTF-8 のバイト数で数える（Swift の文字数ではない）。
  /// 「こんにちは 」は 6 文字だが 16 バイトなので、リンクは 16 バイト目から始まる
  @Test func facetOffsetsAreUTF8Bytes() throws {
    let post = try decode(Post.self, postJSON)
    let text = try #require(post.record?.text)
    let index = try #require(post.record?.facets?.first?.index)
    let bytes = Array(text.utf8)
    let linked = String(decoding: bytes[index.byteStart..<index.byteEnd], as: UTF8.self)
    #expect(linked == "https://example.com")
  }

  /// ラベルの sig は仕様上 {"$bytes": ...} のオブジェクト。これでデコードが落ちるとフィードごと読めない
  @Test func labelWithSignatureObjectDecodes() throws {
    let post = try decode(Post.self, postJSON)
    #expect(post.labels?.first?.val == "porn")
    #expect(post.isSensitive)
  }

  @Test func negatedLabelIsNotSensitive() throws {
    let post = Post(
      uri: "u", cid: nil, author: nil, record: nil,
      labels: [label("porn", neg: true), label("unrelated")])
    #expect(!post.isSensitive)
  }

  /// 引用＋画像（recordWithMedia）は record の中にもう一段 record がある
  @Test func recordWithMediaUnwrapsNestedRecord() throws {
    let embed = try decode(
      Embed.self,
      #"""
      {
        "$type": "app.bsky.embed.recordWithMedia#view",
        "media": {"$type": "app.bsky.embed.images#view", "images": [
          {"thumb": "https://cdn/t.jpg", "fullsize": "https://cdn/f.jpg", "alt": "",
           "aspectRatio": {"width": 4, "height": 3}}
        ]},
        "record": {"$type": "app.bsky.embed.record#view", "record": {
          "$type": "app.bsky.embed.record#viewRecord",
          "uri": "at://did:plc:q/app.bsky.feed.post/1",
          "author": {"did": "did:plc:q", "handle": "quoted.bsky.social"},
          "value": {"text": "引用元"}
        }}
      }
      """#)
    #expect(embed.media?.images?.count == 1)
    #expect(embed.record?.uri == "at://did:plc:q/app.bsky.feed.post/1")
    #expect(embed.record?.value?.text == "引用元")
  }

  @Test func plainRecordEmbedIsNotUnwrapped() throws {
    let embed = try decode(
      Embed.self,
      #"""
      {"$type": "app.bsky.embed.record#view", "record": {
        "$type": "app.bsky.feed.defs#generatorView",
        "uri": "at://did:plc:f/app.bsky.feed.generator/x",
        "displayName": "Discover", "creator": {"did": "did:plc:f"}
      }}
      """#)
    #expect(embed.record?.isFeedGenerator == true)
    #expect(embed.record?.displayName == "Discover")
  }

  /// `Embed.type` は "type" キーを読むため、`$type` しか無い実際の応答では nil になる。
  /// 埋め込みの種類は images / record / media / playlist の有無で判断すること
  @Test func embedTypeIsNilForRealResponses() throws {
    let embed = try decode(
      Embed.self,
      #"{"$type": "app.bsky.embed.video#view", "cid": "bafy", "playlist": "https://video/p.m3u8"}"#)
    #expect(embed.type == nil)
    #expect(embed.playlist == "https://video/p.m3u8")
  }

  /// uploadBlob の応答は blob.ref.$link 形式。旧形式（blob.cid）も受ける
  @Test func uploadBlobResponseAcceptsBothShapes() throws {
    let current = try decode(
      UploadBlobResponse.self,
      #"{"blob": {"$type": "blob", "ref": {"$link": "bafkreiabc"}, "mimeType": "image/jpeg", "size": 1234}}"#
    )
    #expect(current.blob.cid == "bafkreiabc")
    #expect(current.blob.mimeType == "image/jpeg")
    let legacy = try decode(
      UploadBlobResponse.self, #"{"blob": {"cid": "bafylegacy", "mimeType": "image/png"}}"#)
    #expect(legacy.blob.cid == "bafylegacy")
  }

  @Test func uploadBlobResponseWithoutCidFails() {
    #expect(throws: (any Error).self) {
      try decode(UploadBlobResponse.self, #"{"blob": {"mimeType": "image/png"}}"#)
    }
  }

  @Test func hashtagFeedTabIsDistinctFromHome() {
    let tab = FeedTab.forHashtag("swift")
    #expect(tab.id == "hashtag:swift")
    #expect(tab.name == "#swift")
    #expect(tab.hashtag == "swift")
    #expect(tab.uri == nil)
    #expect(tab.id != FeedTab.home.id)
  }
}

func label(_ val: String, neg: Bool? = nil) -> Label {
  Label(ver: nil, src: "did:plc:mod", uri: "u", cid: nil, val: val, neg: neg, cts: nil, exp: nil)
}
