import Foundation

typealias HTTPHeaders = [String: String]

enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
}

/// 2xx 以外の応答。429（レート制限）などは `statusCode` で見分ける
struct HTTPError: LocalizedError {
  let url: URL?
  let statusCode: Int
  let body: Data

  var errorDescription: String? {
    // AT Protocol のエラー応答は {"error": ..., "message": ...}
    let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    let message = json?["message"] as? String ?? json?["error"] as? String
    return message.map { "HTTP \(statusCode): \($0)" } ?? "HTTP \(statusCode)"
  }
}

/// URLSession の薄いラッパー。Alamofire から移行したときの既定の挙動
/// （GET パラメータはキー順にクエリへ、POST の json は JSON 本文へ、2xx 以外は throw）をそのまま持つ
enum HTTPClient {
  private static let session: URLSession = {
    let config = URLSessionConfiguration.default
    // フィードや検索の言語判定に使われるため、Alamofire と同じく端末の言語を送る
    config.httpAdditionalHeaders = [
      "Accept-Language": Locale.preferredLanguages.prefix(6).enumerated()
        .map { "\($1);q=\(1.0 - Double($0) * 0.1)" }.joined(separator: ", ")
    ]
    return URLSession(configuration: config)
  }()

  /// - Parameters:
  ///   - query: URL のクエリにする値。`[String: Any]` か Encodable。nil の項目は送らない
  ///   - json: JSON 本文にする値。`[String: Any]` か Encodable
  static func data(
    _ url: String, method: HTTPMethod = .get, query: Any? = nil, json: Any? = nil,
    headers: HTTPHeaders = [:]
  ) async throws -> Data {
    guard var components = URLComponents(string: url) else { throw URLError(.badURL) }
    if let query {
      let items = try dictionary(from: query).sorted { $0.key < $1.key }
        .map { "\(escape($0.key))=\(escape(stringValue($0.value)))" }
      components.percentEncodedQuery = ([components.percentEncodedQuery].compactMap { $0 } + items)
        .joined(separator: "&")
    }
    guard let resolved = components.url else { throw URLError(.badURL) }

    var request = URLRequest(url: resolved)
    request.httpMethod = method.rawValue
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    if let json {
      request.httpBody = try jsonData(json)
      if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      }
    }
    return try await send(request)
  }

  static func decode<T: Decodable>(
    _ type: T.Type, _ url: String, method: HTTPMethod = .get, query: Any? = nil, json: Any? = nil,
    headers: HTTPHeaders = [:], decoder: JSONDecoder = JSONDecoder()
  ) async throws -> T {
    let data = try await data(url, method: method, query: query, json: json, headers: headers)
    return try decoder.decode(T.self, from: data)
  }

  /// 組み立て済みのリクエストを送り、2xx 以外なら `HTTPError` を投げる
  static func send(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(statusCode) else {
      dlog(
        "HTTP \(statusCode) \(request.url?.absoluteString ?? "") \(String(decoding: data, as: UTF8.self))"
      )
      throw HTTPError(url: request.url, statusCode: statusCode, body: data)
    }
    return data
  }

  private static func jsonData(_ value: Any) throws -> Data {
    if let encodable = value as? Encodable { return try JSONEncoder().encode(encodable) }
    return try JSONSerialization.data(withJSONObject: value)
  }

  private static func dictionary(from value: Any) throws -> [String: Any] {
    if let dict = value as? [String: Any] { return dict }
    return try JSONSerialization.jsonObject(with: jsonData(value)) as? [String: Any] ?? [:]
  }

  private static func stringValue(_ value: Any) -> String {
    // Bool も NSNumber として 1 / 0 になる（Alamofire の既定と同じ）
    (value as? NSNumber)?.stringValue ?? "\(value)"
  }

  /// Alamofire の URLEncoding と同じく、クエリ値の区切り文字（&=+ など）もエスケープする
  private static func escape(_ string: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
    return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
  }
}
