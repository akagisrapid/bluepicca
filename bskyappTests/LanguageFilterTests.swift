import Foundation
import Testing

@testable import bskyapp

/// 言語フィルタの判定。「何も選んでいなければ絞らない」「言語のない投稿は出す」
/// 「地域付きのタグも主言語で照合する」を固定する
struct LanguageFilterMatchingTests {
  @Test func noSelectionShowsEverything() {
    #expect(LanguageFilterManager.allows(["en"], allowed: []))
    #expect(LanguageFilterManager.allows(nil, allowed: []))
  }

  @Test func postWithoutLanguageIsShown() {
    #expect(LanguageFilterManager.allows(nil, allowed: ["ja"]))
    #expect(LanguageFilterManager.allows([], allowed: ["ja"]))
  }

  @Test func onlySelectedLanguagesAreShown() {
    #expect(LanguageFilterManager.allows(["ja"], allowed: ["ja"]))
    #expect(!LanguageFilterManager.allows(["en"], allowed: ["ja"]))
    #expect(LanguageFilterManager.allows(["en"], allowed: ["ja", "en"]))
  }

  @Test func anyMatchingLanguageIsEnough() {
    #expect(LanguageFilterManager.allows(["en", "ja"], allowed: ["ja"]))
    #expect(!LanguageFilterManager.allows(["en", "ko"], allowed: ["ja"]))
  }

  @Test func regionAndScriptAreIgnored() {
    #expect(LanguageFilterManager.allows(["en-US"], allowed: ["en"]))
    #expect(LanguageFilterManager.allows(["zh-Hant-TW"], allowed: ["zh"]))
    #expect(LanguageFilterManager.allows(["pt_BR"], allowed: ["pt"]))
    #expect(LanguageFilterManager.allows(["JA"], allowed: ["ja"]))
  }

  @Test func primaryTag() {
    #expect(LanguageFilterManager.primaryTag("en-US") == "en")
    #expect(LanguageFilterManager.primaryTag("zh_Hant") == "zh")
    #expect(LanguageFilterManager.primaryTag("ja") == "ja")
    #expect(LanguageFilterManager.primaryTag("") == "")
  }
}

@Suite(.serialized)
struct LanguageFilterManagerTests {
  private let manager = LanguageFilterManager.shared

  private func withAllowed(_ languages: Set<String>, _ body: () -> Void) {
    let saved = manager.allowedLanguages
    manager.allowedLanguages = languages
    defer { manager.allowedLanguages = saved }
    body()
  }

  @Test func toggleAddsAndRemoves() {
    withAllowed([]) {
      #expect(!manager.isActive)
      manager.toggle("ja")
      #expect(manager.allowedLanguages == ["ja"])
      #expect(manager.isActive)
      #expect(!manager.allows(["en"]))
      manager.toggle("ja")
      #expect(manager.allowedLanguages.isEmpty)
      #expect(manager.allows(["en"]))
    }
  }

  @Test func summaryListsSelectedLanguagesInCandidateOrder() {
    withAllowed([]) {
      #expect(manager.summary == nil)
    }
    withAllowed(["en", "ja"]) {
      let summary = manager.summary ?? ""
      let ja = LanguageFilterManager.displayName("ja")
      let en = LanguageFilterManager.displayName("en")
      #expect(summary.contains(ja))
      #expect(summary.contains(en))
      // 候補の並び（日本語が先）で出す
      if let jaRange = summary.range(of: ja), let enRange = summary.range(of: en) {
        #expect(jaRange.lowerBound < enRange.lowerBound)
      }
    }
  }
}
