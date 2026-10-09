import Foundation
import SwiftUI
import Testing
import UIKit

@testable import bskyapp

struct OpenGraphParserTests {
  @Test func readsPropertyBeforeOrAfterContent() {
    let html = #"""
      <meta property="og:title" content="タイトル">
      <meta content='説明文' property='og:description'>
      <meta property="og:image" content="https://example.com/a.png">
      """#
    let meta = OpenGraphParser.parse(html: html)
    #expect(meta.title == "タイトル")
    #expect(meta.description == "説明文")
    #expect(meta.imageURL == "https://example.com/a.png")
  }

  @Test func decodesCommonEntities() {
    let meta = OpenGraphParser.parse(
      html: #"<meta property="og:title" content="Tom &amp; Jerry &lt;3 &#39;s">"#)
    #expect(meta.title == "Tom & Jerry <3 's")
  }

  @Test func fallsBackToTitleTag() {
    let meta = OpenGraphParser.parse(html: "<html><head><title>ページ名</title></head></html>")
    #expect(meta.title == "ページ名")
    #expect(meta.description == nil)
    #expect(meta.imageURL == nil)
  }
}

struct StringExtensionTests {
  @Test func parsesTimestampsWithAndWithoutMilliseconds() throws {
    let withMs = try #require("2026-10-01T12:34:56.789Z".parseToDateRemovingMilliseconds)
    let withoutMs = try #require("2026-10-01T12:34:56Z".parseToDateRemovingMilliseconds)
    #expect(withMs == withoutMs)
    #expect(withoutMs.timeIntervalSince1970 == 1_790_858_096)
  }

  @Test func invalidTimestampIsNil() {
    #expect("not a date".parseToDateRemovingMilliseconds == nil)
  }
}

@Suite(.serialized)
struct UserHighlightManagerTests {
  private let manager = UserHighlightManager.shared

  @Test func hexIsConvertedToColor() throws {
    let did = "did:plc:highlight-test"
    defer { manager.remove(did: did) }
    manager.set(did: did, hex: "#4D96FF")
    let color = try #require(manager.color(for: did))
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    #expect(abs(r - 0x4D / 255) < 0.01)
    #expect(abs(g - 0x96 / 255) < 0.01)
    #expect(abs(b - 0xFF / 255) < 0.01)
  }

  @Test func unknownUserHasNoColor() {
    #expect(manager.color(for: "did:plc:nobody") == nil)
    #expect(!manager.hasHighlight(for: "did:plc:nobody"))
  }
}

struct ImageCompressionHelperTests {
  @Test func sizeLimitIsInclusive() {
    let limit = ImageCompressionHelper.maxFileSizeBytes
    #expect(!ImageCompressionHelper.isFileSizeExceeded(Data(count: limit)))
    #expect(ImageCompressionHelper.isFileSizeExceeded(Data(count: limit + 1)))
  }

  @Test func compressedImageFitsTheLimit() throws {
    let size = CGSize(width: 4000, height: 3000)
    let image = UIGraphicsImageRenderer(size: size).image { context in
      for i in 0..<200 {
        UIColor(hue: CGFloat(i) / 200, saturation: 1, brightness: 1, alpha: 1).setFill()
        context.fill(CGRect(x: CGFloat(i) * 20, y: 0, width: 20, height: size.height))
      }
    }
    let data = try #require(ImageCompressionHelper.compressImage(image))
    #expect(data.count <= ImageCompressionHelper.maxFileSizeBytes)
  }
}

/// 文言は日本語を原文に、英訳を String Catalog に持たせている。カタログがバンドルに入っていないと
/// ビルドは通ったまま英語環境で日本語が出るので、英訳が引けることを固定する
struct LocalizationTests {
  @Test func englishTranslationIsBundled() throws {
    let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
    let en = try #require(Bundle(path: path))
    #expect(en.localizedString(forKey: "いいね", value: nil, table: nil) == "Like")
    #expect(en.localizedString(forKey: "非表示", value: nil, table: nil) == "Hidden")
  }
}
