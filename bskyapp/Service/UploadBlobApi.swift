import Foundation

public struct UploadBlobResponse: Codable {
  public let blob: BlobReference

  // 手動で初期化するためのイニシャライザ
  public init(blob: BlobReference) {
    self.blob = blob
  }

  // デコード用の初期化メソッドを追加
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    do {
      // まず、blobフィールドを取得
      if let blobContainer = try? container.nestedContainer(
        keyedBy: BlobCodingKeys.self, forKey: .blob)
      {
        // 標準的なレスポンス形式の場合
        if let cid = try? blobContainer.decode(String.self, forKey: .cid),
          let mimeType = try? blobContainer.decode(String.self, forKey: .mimeType)
        {
          blob = BlobReference(cid: cid, mimeType: mimeType)
          return
        }

        // refフィールドがある場合
        if let refContainer = try? blobContainer.nestedContainer(
          keyedBy: RefCodingKeys.self, forKey: .ref)
        {
          if let link = try? refContainer.decode(String.self, forKey: .link) {
            let mimeType = try blobContainer.decode(String.self, forKey: .mimeType)
            blob = BlobReference(cid: link, mimeType: mimeType)
            return
          }
        }
      }

      // 別の形式の場合、直接オブジェクトとして取得
      blob = try container.decode(BlobReference.self, forKey: .blob)
    } catch {
      dlog("UploadBlobResponse デコードエラー: \(error)")

      // デコードに失敗した場合はエラーを投げる
      throw error
    }
  }

  // エンコード用のメソッドを追加
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(blob, forKey: .blob)
  }

  private enum CodingKeys: String, CodingKey {
    case blob
  }

  private enum BlobCodingKeys: String, CodingKey {
    case cid, mimeType, ref
  }

  private enum RefCodingKeys: String, CodingKey {
    case link = "$link"
  }
}

// 他のファイルからも参照できるように、publicキーワードを追加
public struct BlobReference: Codable {
  public let cid: String
  public let mimeType: String

  // デコード用の初期化メソッドを追加
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // 標準的な形式の場合
    if let cid = try? container.decode(String.self, forKey: .cid),
      let mimeType = try? container.decode(String.self, forKey: .mimeType)
    {
      self.cid = cid
      self.mimeType = mimeType
      return
    }

    // 別の形式の場合、refフィールドから取得
    if let refContainer = try? container.nestedContainer(keyedBy: RefCodingKeys.self, forKey: .ref)
    {
      if let link = try? refContainer.decode(String.self, forKey: .link) {
        self.cid = link
        self.mimeType = try container.decode(String.self, forKey: .mimeType)
        return
      }
    }

    // それでも取得できない場合はエラー
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: container.codingPath,
        debugDescription: "Could not decode BlobReference"
      )
    )
  }

  // エンコード用のメソッドを追加
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(cid, forKey: .cid)
    try container.encode(mimeType, forKey: .mimeType)
  }

  // 手動で初期化するためのイニシャライザ
  public init(cid: String, mimeType: String) {
    self.cid = cid
    self.mimeType = mimeType
  }

  private enum CodingKeys: String, CodingKey {
    case cid, mimeType, ref
  }

  private enum RefCodingKeys: String, CodingKey {
    case link = "$link"
  }
}
