import Foundation

/// Bluesky のミュートワード設定（app.bsky.actor.defs#mutedWordsPref）を読み書きする。
/// putPreferences は設定全体を置き換えるので、ほかの設定は取得したまま戻す
struct MutedWordsPreferenceApi {
  static let prefType = "app.bsky.actor.defs#mutedWordsPref"
  private let getUrl = "https://bsky.social/xrpc/app.bsky.actor.getPreferences"
  private let putUrl = "https://bsky.social/xrpc/app.bsky.actor.putPreferences"

  /// サーバーに設定が無ければ nil（一度も同期していない）
  func getMutedWords() async throws -> [MuteWord]? {
    let prefs = try await fetchPreferences()
    guard let pref = prefs.first(where: { $0["$type"] as? String == Self.prefType }) else {
      return nil
    }
    return (pref["items"] as? [[String: Any]] ?? []).compactMap(Self.muteWord(from:))
  }

  func putMutedWords(_ words: [MuteWord]) async throws {
    var prefs = try await fetchPreferences()
    prefs.removeAll { $0["$type"] as? String == Self.prefType }
    prefs.append(["$type": Self.prefType, "items": words.map(Self.item(from:))])

    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = [
      "Authorization": "Bearer \(session.accessJwt)",
      "Content-Type": "application/json",
    ]
    _ = try await HTTPClient.data(
      putUrl, method: .post, json: ["preferences": prefs], headers: headers)
  }

  private func fetchPreferences() async throws -> [[String: Any]] {
    let session = try await SessionManager.shared.getSession()
    let data = try await HTTPClient.data(
      getUrl, headers: ["Authorization": "Bearer \(session.accessJwt)"])
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw URLError(.cannotParseResponse)
    }
    return json["preferences"] as? [[String: Any]] ?? []
  }

  // MARK: - 変換（app.bsky.actor.defs#mutedWord）

  static func muteWord(from item: [String: Any]) -> MuteWord? {
    guard let value = item["value"] as? String, !value.isEmpty else { return nil }
    let targets = item["targets"] as? [String] ?? []
    return MuteWord(
      value: value,
      // 公式アプリの「タグのみ」は ["tag"]、「本文とタグ」は ["content", "tag"]
      target: targets.contains("content") ? .content : .tag,
      expiresAt: (item["expiresAt"] as? String).flatMap(parseDate),
      serverId: item["id"] as? String,
      actorTarget: item["actorTarget"] as? String)
  }

  static func item(from word: MuteWord) -> [String: Any] {
    var item: [String: Any] = [
      "value": word.value,
      "targets": word.target == .content ? ["content", "tag"] : ["tag"],
      "actorTarget": word.actorTarget ?? "all",
    ]
    if let id = word.serverId { item["id"] = id }
    if let expiresAt = word.expiresAt {
      item["expiresAt"] = ISO8601DateFormatter.withFractionalSeconds.string(from: expiresAt)
    }
    return item
  }

  private static func parseDate(_ string: String) -> Date? {
    ISO8601DateFormatter.withFractionalSeconds.date(from: string)
      ?? ISO8601DateFormatter().date(from: string)
  }
}

extension ISO8601DateFormatter {
  fileprivate static let withFractionalSeconds: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
}
