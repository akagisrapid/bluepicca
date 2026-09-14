import Alamofire
import Foundation
import UIKit

class PostCreationService {
  static let shared = PostCreationService()

  private let endPoint = "https://bsky.social/xrpc/"

  private init() {}

  // MARK: - Image Upload

  func uploadImages(
    _ images: [ImageToUpload],
    onProgress: @escaping (Double) -> Void
  ) async throws -> [UploadedImage] {
    var uploadedImages: [UploadedImage] = []
    let totalImages = images.count

    for (index, imageToUpload) in images.enumerated() {
      onProgress(Double(index) / Double(totalImages))

      guard let imageData = ImageCompressionHelper.compressImage(imageToUpload.image) else {
        dlog("画像[\(index)]の圧縮に失敗")
        continue
      }

      if ImageCompressionHelper.isFileSizeExceeded(imageData) {
        let fileSizeString = ImageCompressionHelper.formatFileSize(imageData.count)
        dlog("画像[\(index)]がファイルサイズ制限を超えています: \(fileSizeString)")
        continue
      }

      do {
        let blobResponse = try await uploadBlob(imageData: imageData)

        let uploadedImage = UploadedImage(
          blobReference: blobResponse.blob,
          alt: imageToUpload.alt,
          imageData: imageData
        )
        uploadedImages.append(uploadedImage)

        onProgress(Double(index + 1) / Double(totalImages))
      } catch {
        dlog("画像[\(index)]のアップロード失敗: \(error)")
      }
    }

    return uploadedImages
  }

  // MARK: - Post Creation

  func createPost(
    text: String,
    images: [UploadedImage]?,
    threadgateRules: Set<ThreadgateRule> = [],
    replyDisabled: Bool = false,
    quotingDisabled: Bool = false
  ) async throws {
    let session = try await SessionManager.shared.getSession()

    var recordDict: [String: Any] = [
      "$type": "app.bsky.feed.post",
      "text": text,
      "createdAt": Date().ISO8601Format(),
    ]

    if let images = images, !images.isEmpty {
      recordDict["embed"] = buildImageEmbed(images)
    } else if let externalEmbed = await buildExternalEmbedIfPresent(in: text) {
      recordDict["embed"] = externalEmbed
    }

    let paramDict: [String: Any] = [
      "repo": session.did,
      "collection": "app.bsky.feed.post",
      "record": recordDict,
    ]

    let response = try await sendCreateRecord(paramDict: paramDict, session: session)

    if let postUri = response.uri {
      if replyDisabled {
        try await createThreadgate(postUri: postUri, allowArray: [], session: session)
      } else if !threadgateRules.isEmpty {
        try await createThreadgate(
          postUri: postUri, allowArray: threadgateRules.map { $0.allowDict }, session: session)
      }
      if quotingDisabled {
        try await createPostgate(postUri: postUri, session: session)
      }
    }
  }

  // MARK: - Quote Post Creation

  func createQuotePost(
    text: String,
    images: [UploadedImage]?,
    quotedUri: String,
    quotedCid: String
  ) async throws {
    let session = try await SessionManager.shared.getSession()

    let recordReference: [String: Any] = ["uri": quotedUri, "cid": quotedCid]

    let embed: [String: Any]
    if let images = images, !images.isEmpty {
      embed = [
        "$type": "app.bsky.embed.recordWithMedia",
        "record": [
          "$type": "app.bsky.embed.record",
          "record": recordReference,
        ],
        "media": buildImageEmbed(images),
      ]
    } else {
      embed = [
        "$type": "app.bsky.embed.record",
        "record": recordReference,
      ]
    }

    let recordDict: [String: Any] = [
      "$type": "app.bsky.feed.post",
      "text": text,
      "createdAt": Date().ISO8601Format(),
      "embed": embed,
    ]

    let paramDict: [String: Any] = [
      "repo": session.did,
      "collection": "app.bsky.feed.post",
      "record": recordDict,
    ]

    try await sendCreateRecord(paramDict: paramDict, session: session)
  }

  // MARK: - Reply Creation

  func createReply(
    text: String,
    images: [UploadedImage]?,
    parentUri: String,
    parentCid: String
  ) async throws {
    let session = try await SessionManager.shared.getSession()

    let replyRef: [String: Any] = [
      "root": ["uri": parentUri, "cid": parentCid],
      "parent": ["uri": parentUri, "cid": parentCid],
    ]

    var recordDict: [String: Any] = [
      "$type": "app.bsky.feed.post",
      "text": text,
      "createdAt": Date().ISO8601Format(),
      "reply": replyRef,
    ]

    if let images = images, !images.isEmpty {
      recordDict["embed"] = buildImageEmbed(images)
    } else if let externalEmbed = await buildExternalEmbedIfPresent(in: text) {
      recordDict["embed"] = externalEmbed
    }

    let paramDict: [String: Any] = [
      "repo": session.did,
      "collection": "app.bsky.feed.post",
      "record": recordDict,
    ]

    try await sendCreateRecord(paramDict: paramDict, session: session)
  }

  // MARK: - Link Card (external embed) Generation

  /// テキスト中の最初のURLからOGPを取得し、app.bsky.embed.external を組み立てる。
  /// 取得に失敗した場合は nil を返し、呼び出し側は埋め込みなしで投稿を続行する。
  private func buildExternalEmbedIfPresent(in text: String) async -> [String: Any]? {
    guard let url = firstURL(in: text) else { return nil }

    guard let html = try? await fetchString(url: url) else { return nil }
    let metadata = OpenGraphParser.parse(html: html)

    var external: [String: Any] = [
      "uri": url.absoluteString,
      "title": metadata.title ?? url.host ?? url.absoluteString,
      "description": metadata.description ?? "",
    ]

    if let imageURLString = metadata.imageURL,
      let imageURL = URL(string: imageURLString, relativeTo: url),
      let imageData = try? await fetchData(url: imageURL),
      let thumbImage = UIImage(data: imageData),
      let compressed = ImageCompressionHelper.compressImage(thumbImage),
      let blobResponse = try? await uploadBlob(imageData: compressed)
    {
      external["thumb"] = [
        "$type": "blob",
        "ref": ["$link": blobResponse.blob.cid],
        "mimeType": blobResponse.blob.mimeType,
        "size": compressed.count,
      ]
    }

    return ["$type": "app.bsky.embed.external", "external": external]
  }

  private func firstURL(in text: String) -> URL? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    return detector.matches(in: text, range: range).first?.url
  }

  private func fetchString(url: URL) async throws -> String {
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    let response = await AF.request(request).validate()
      .serializingString(encoding: .utf8)
      .response
    switch response.result {
    case .success(let value): return value
    case .failure(let error): throw error
    }
  }

  private func fetchData(url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    let response = await AF.request(request).validate()
      .serializingData()
      .response
    switch response.result {
    case .success(let value): return value
    case .failure(let error): throw error
    }
  }

  // MARK: - Private Helpers

  private func uploadBlob(imageData: Data) async throws -> UploadBlobResponse {
    let urlString = endPoint + "com.atproto.repo.uploadBlob"
    let session = try await SessionManager.shared.getSession()

    let headers: HTTPHeaders = [
      "Content-Type": "image/jpeg",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    let response = await AF.upload(imageData, to: urlString, method: .post, headers: headers)
      .validate()
      .serializingDecodable(UploadBlobResponse.self)
      .response

    switch response.result {
    case .success(let value):
      return value
    case .failure(let error):
      throw error
    }
  }

  private func buildImageEmbed(_ images: [UploadedImage]) -> [String: Any] {
    let imagesArray: [[String: Any]] = images.map { image in
      [
        "alt": image.alt,
        "image": [
          "$type": "blob",
          "ref": ["$link": image.blobReference.cid],
          "mimeType": image.blobReference.mimeType,
          "size": image.imageData.count,
        ],
      ]
    }

    return [
      "$type": "app.bsky.embed.images",
      "images": imagesArray,
    ]
  }

  // MARK: - Threadgate Creation

  private func createThreadgate(
    postUri: String, allowArray: [[String: Any]], session: CreateSessionResponse
  ) async throws {
    guard let rkey = postUri.components(separatedBy: "/").last else { return }

    let recordDict: [String: Any] = [
      "$type": "app.bsky.feed.threadgate",
      "post": postUri,
      "allow": allowArray,
      "createdAt": Date().ISO8601Format(),
    ]

    let paramDict: [String: Any] = [
      "repo": session.did,
      "collection": "app.bsky.feed.threadgate",
      "rkey": rkey,
      "record": recordDict,
    ]

    _ = try await sendCreateRecord(paramDict: paramDict, session: session)
  }

  private func createPostgate(postUri: String, session: CreateSessionResponse) async throws {
    guard let rkey = postUri.components(separatedBy: "/").last else { return }

    let recordDict: [String: Any] = [
      "$type": "app.bsky.feed.postgate",
      "post": postUri,
      "embeddingRules": [["$type": "app.bsky.feed.postgate#disableRule"]],
      "createdAt": Date().ISO8601Format(),
    ]

    let paramDict: [String: Any] = [
      "repo": session.did,
      "collection": "app.bsky.feed.postgate",
      "rkey": rkey,
      "record": recordDict,
    ]

    _ = try await sendCreateRecord(paramDict: paramDict, session: session)
  }

  @discardableResult
  private func sendCreateRecord(paramDict: [String: Any], session: CreateSessionResponse)
    async throws -> CreateRecordResponse
  {
    let urlString = endPoint + "com.atproto.repo.createRecord"

    let headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer \(session.accessJwt)",
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: paramDict, options: [])

    var request = URLRequest(url: URL(string: urlString)!)
    request.httpMethod = "POST"
    request.httpBody = jsonData

    headers.forEach { header in
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    let response = await AF.request(request)
      .validate()
      .serializingDecodable(CreateRecordResponse.self)
      .response

    switch response.result {
    case .success(let value):
      return value
    case .failure(let error):
      throw error
    }
  }
}

// MARK: - ThreadgateRule

enum ThreadgateRule: String, CaseIterable, Hashable {
  case mentioned
  case followed
  case follower

  var allowDict: [String: Any] {
    switch self {
    case .mentioned: return ["$type": "app.bsky.feed.threadgate#mentionRule"]
    case .followed: return ["$type": "app.bsky.feed.threadgate#followingRule"]
    case .follower: return ["$type": "app.bsky.feed.threadgate#followerRule"]
    }
  }

  var label: String {
    switch self {
    case .mentioned: return String(localized: "メンションした人")
    case .followed: return String(localized: "フォロー中")
    case .follower: return String(localized: "フォロワー")
    }
  }

  var icon: String {
    switch self {
    case .mentioned: return "at"
    case .followed: return "person.badge.plus"
    case .follower: return "person.2.fill"
    }
  }
}

/// Input model for images to be uploaded
struct ImageToUpload {
  let image: UIImage
  let alt: String
}
