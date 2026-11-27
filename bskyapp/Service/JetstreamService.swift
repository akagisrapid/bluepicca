import Foundation

/// Jetstream（Bluesky の全投稿が流れる WebSocket）から、指定した人の投稿・リポストだけを受け取る。
/// 中身は使わず「新着があった」という合図としてだけ使い、本文は getTimeline で取り直す
/// （返信の絞り込みやミュートを公式 TL と同じにするため）
enum JetstreamService {
  static let endpoint = "wss://jetstream2.us-east.bsky.network/subscribe"
  /// Jetstream が一度に受け付ける DID の上限
  static let maxDids = 10_000

  /// キャンセルされるまで接続を保ち、切れたらつなぎ直す。新着ごとに `onEvent` を呼ぶ
  static func run(dids: [String], onEvent: @escaping () async -> Void) async {
    var retryDelay: Double = 1
    while !Task.isCancelled {
      do {
        try await connect(dids: dids, onConnected: { retryDelay = 1 }, onEvent: onEvent)
      } catch {
        dlog("Jetstream: disconnected: \(error)")
      }
      guard !Task.isCancelled else { return }
      try? await Task.sleep(for: .seconds(retryDelay))
      retryDelay = min(retryDelay * 2, 60)
      // つなぎ直したあいだの取りこぼしは、合図を1回出して getTimeline で埋める
      await onEvent()
    }
  }

  private static func connect(
    dids: [String], onConnected: () -> Void, onEvent: () async -> Void
  ) async throws {
    // DID が多いと URL に収まらないので、requireHello で待たせてから options_update で送る
    var components = URLComponents(string: endpoint)!
    components.queryItems = [URLQueryItem(name: "requireHello", value: "true")]
    let task = URLSession.shared.webSocketTask(with: components.url!)
    task.maximumMessageSize = 4 * 1024 * 1024
    task.resume()
    defer { task.cancel(with: .goingAway, reason: nil) }

    let options: [String: Any] = [
      "type": "options_update",
      "payload": [
        "wantedCollections": ["app.bsky.feed.post", "app.bsky.feed.repost"],
        "wantedDids": Array(dids.prefix(maxDids)),
      ],
    ]
    let optionsData = try JSONSerialization.data(withJSONObject: options)
    try await task.send(.string(String(decoding: optionsData, as: UTF8.self)))
    onConnected()
    dlog("Jetstream: connected (\(dids.count) dids)")

    try await withTaskCancellationHandler {
      while !Task.isCancelled {
        let message = try await task.receive()
        if isNewRecord(message) { await onEvent() }
      }
    } onCancel: {
      task.cancel(with: .goingAway, reason: nil)
    }
  }

  /// commit の create だけを新着とみなす（削除やプロフィール更新などは無視）
  static func isNewRecord(_ message: URLSessionWebSocketTask.Message) -> Bool {
    let data: Data
    switch message {
    case .string(let text): data = Data(text.utf8)
    case .data(let raw): data = raw
    @unknown default: return false
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      json["kind"] as? String == "commit",
      let commit = json["commit"] as? [String: Any]
    else { return false }
    return commit["operation"] as? String == "create"
  }

  /// 自分とフォロー中の人の DID（Following TL に出る人）
  static func timelineDids(actor: String) async throws -> [String] {
    var dids = [actor]
    var cursor: String?
    repeat {
      let response = try await GetFollowsApi.getFollows(
        param: GetFollowsApiRequest(actor: actor, limit: 100, cursor: cursor))
      dids += response.follows.map(\.did)
      cursor = response.follows.isEmpty ? nil : response.cursor
    } while cursor != nil && dids.count < maxDids
    return dids
  }
}
