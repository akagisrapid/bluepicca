import Foundation
import Testing

@testable import bskyapp

/// アクセストークンは 2 時間で切れるので、期限は JWT の exp で判定する
struct SessionManagerTests {
  private func jwt(exp: TimeInterval) -> String {
    let payload = try! JSONSerialization.data(withJSONObject: ["exp": exp, "sub": "did:plc:test"])
    let base64url = payload.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return "eyJhbGciOiJIUzI1NiJ9.\(base64url).sig"
  }

  @Test func tokenWithTimeLeftIsValid() {
    let now = Date()
    #expect(SessionManager.isAccessTokenValid(jwt(exp: now.timeIntervalSince1970 + 3600), now: now))
  }

  @Test func expiredOrAlmostExpiredTokenIsInvalid() {
    let now = Date()
    #expect(!SessionManager.isAccessTokenValid(jwt(exp: now.timeIntervalSince1970 - 1), now: now))
    #expect(!SessionManager.isAccessTokenValid(jwt(exp: now.timeIntervalSince1970 + 30), now: now))
  }

  @Test func unreadableTokenIsInvalid() {
    #expect(!SessionManager.isAccessTokenValid("not-a-jwt"))
    #expect(!SessionManager.isAccessTokenValid("a.@@@.c"))
  }
}
