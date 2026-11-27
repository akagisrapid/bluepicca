import Testing

@testable import bskyapp

struct AppInfoTests {
  @Test func combinesVersionAndBuild() {
    let info: [String: Any] = ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "1"]
    #expect(AppInfo.versionString(from: info) == "1.2 (1)")
  }

  @Test func fallsBackWhenKeysAreMissing() {
    #expect(AppInfo.versionString(from: ["CFBundleShortVersionString": "1.2"]) == "1.2")
    #expect(AppInfo.versionString(from: ["CFBundleVersion": "7"]) == "(7)")
    #expect(AppInfo.versionString(from: nil) == "-")
  }

  @Test func mainBundleHasVersion() {
    #expect(AppInfo.versionString != "-")
  }
}
