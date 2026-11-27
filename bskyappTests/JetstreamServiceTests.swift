import Foundation
import Testing

@testable import bskyapp

/// Jetstream のメッセージのうち、TL を取り直す合図にするのは投稿・リポストの作成だけ
struct JetstreamServiceTests {
  private func message(_ json: String) -> URLSessionWebSocketTask.Message { .string(json) }

  @Test func createCommitIsNewRecord() {
    #expect(
      JetstreamService.isNewRecord(
        message(
          #"{"did":"did:plc:x","kind":"commit","commit":{"operation":"create","collection":"app.bsky.feed.post"}}"#
        )))
  }

  @Test func deleteAndNonCommitAreIgnored() {
    #expect(
      !JetstreamService.isNewRecord(
        message(#"{"did":"did:plc:x","kind":"commit","commit":{"operation":"delete"}}"#)))
    #expect(!JetstreamService.isNewRecord(message(#"{"did":"did:plc:x","kind":"identity"}"#)))
    #expect(!JetstreamService.isNewRecord(message("not json")))
  }
}
