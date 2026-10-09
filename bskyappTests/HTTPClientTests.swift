import Foundation
import Testing

@testable import bskyapp

/// Alamofire から URLSession に移したとき、Alamofire の既定の挙動（キー順のクエリ、区切り文字のエスケープ、
/// nil の省略、JSON 本文の Content-Type）を引き継いだ。ここが崩れると検索語やカーソルが壊れて届く
struct HTTPClientTests {
  private let base = "https://bsky.social/xrpc/app.bsky.feed.searchPosts"

  private func query(of request: URLRequest) -> String? {
    request.url.flatMap {
      URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedQuery
    }
  }

  @Test func queryKeysAreSorted() throws {
    let request = try HTTPClient.makeRequest(base, query: ["q": "x", "limit": 50, "cursor": "c"])
    #expect(query(of: request) == "cursor=c&limit=50&q=x")
  }

  /// 検索語の & = + がそのまま入ると、サーバーには別のパラメータや空白として届く
  @Test func reservedCharactersAndJapaneseAreEscaped() throws {
    let request = try HTTPClient.makeRequest(base, query: ["q": "a&b=c+d 日本 #x"])
    let encoded = try #require(query(of: request))
    #expect(!encoded.contains("&b"))
    #expect(encoded.contains("%26"))  // &
    #expect(encoded.contains("%3D"))  // =
    #expect(encoded.contains("%2B"))  // +
    let components = try #require(
      request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
    #expect(components.queryItems?.first?.value == "a&b=c+d 日本 #x")
  }

  @Test func encodableQueryOmitsNilValues() throws {
    let request = try HTTPClient.makeRequest(
      base, query: SearchPostsRequest(q: "swift", limit: 50, cursor: nil))
    #expect(query(of: request) == "limit=50&q=swift")
  }

  @Test func boolQueryValuesAreNumeric() throws {
    let request = try HTTPClient.makeRequest(base, query: ["flag": true])
    #expect(query(of: request) == "flag=1")
  }

  @Test func existingQueryInURLIsKept() throws {
    let request = try HTTPClient.makeRequest(base + "?feeds=a", query: ["limit": 1])
    #expect(query(of: request) == "feeds=a&limit=1")
  }

  @Test func jsonBodySetsContentTypeWhenMissing() throws {
    let request = try HTTPClient.makeRequest(
      base, method: .post, json: MuteActorRequest(actor: "did:plc:abc"))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["actor"] as? String == "did:plc:abc")
  }

  @Test func dictionaryJSONBodyIsSerialized() throws {
    let request = try HTTPClient.makeRequest(
      base, method: .post, json: ["record": ["$type": "app.bsky.feed.like"]])
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect((json["record"] as? [String: Any])?["$type"] as? String == "app.bsky.feed.like")
  }

  @Test func explicitHeadersArePassedThroughAndNotOverridden() throws {
    let request = try HTTPClient.makeRequest(
      base, method: .post, json: ["a": 1],
      headers: ["Authorization": "Bearer t", "Content-Type": "application/json; charset=utf-8"])
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8")
  }

  @Test func getWithoutBodyHasNoContentType() throws {
    let request = try HTTPClient.makeRequest(base, query: ["q": "x"])
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
  }

  @Test func invalidURLThrows() {
    #expect(throws: URLError.self) { try HTTPClient.makeRequest("http://[::1", query: ["a": 1]) }
  }
}

struct HTTPErrorTests {
  /// AT Protocol のエラー応答は {"error", "message"}。message があればそれを見せる
  @Test func descriptionUsesATProtocolMessage() {
    let body = Data(#"{"error":"InvalidRequest","message":"Profile not found"}"#.utf8)
    let error = HTTPError(url: nil, statusCode: 400, body: body)
    #expect(error.localizedDescription == "HTTP 400: Profile not found")
  }

  @Test func descriptionFallsBackToErrorThenStatus() {
    let errorOnly = HTTPError(
      url: nil, statusCode: 401, body: Data(#"{"error":"ExpiredToken"}"#.utf8))
    #expect(errorOnly.localizedDescription == "HTTP 401: ExpiredToken")
    let notJSON = HTTPError(url: nil, statusCode: 502, body: Data("<html>".utf8))
    #expect(notJSON.localizedDescription == "HTTP 502")
  }

  /// 429 だけはレート制限の案内に差し替える（ContentViewModel / PostCardViewModel が使う）
  @Test func rateLimitGetsUserFacingMessage() {
    let limited = HTTPError(url: nil, statusCode: 429, body: Data())
    #expect(limited.userFacingMessage == "アクセスが集中しています。しばらくしてから再度お試しください。")
    let other = HTTPError(url: nil, statusCode: 500, body: Data())
    #expect(other.userFacingMessage == other.localizedDescription)
  }
}
