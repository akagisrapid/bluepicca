import Foundation
import UIKit

public class ImageCompressionHelper {
  // app.bsky.embed.images の上限（2026-04 に 1MB から 2MB、長辺 2000px から 4000px に緩和）
  public static let maxFileSizeBytes: Int = 2_000_000
  public static let maxDimension: CGFloat = 4000

  /// 画像を指定されたファイルサイズ以下に圧縮する
  /// 長辺 4000px から始め、品質を下げても収まらなければ長辺を半分ずつ縮める
  public static func compressImage(_ image: UIImage, maxSizeBytes: Int = maxFileSizeBytes) -> Data?
  {
    let compressionQualities: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
    var smallest: UIImage = image

    for dimension in [maxDimension, maxDimension / 2, maxDimension / 4] {
      smallest = resizeImage(image, maxDimension: dimension)
      for quality in compressionQualities {
        if let data = smallest.jpegData(compressionQuality: quality), data.count <= maxSizeBytes {
          dlog("圧縮成功: \(data.count)バイト (長辺: \(dimension), 品質: \(quality))")
          return data
        }
      }
    }

    dlog("警告: ファイルサイズ制限内に収まりませんでした")
    return smallest.jpegData(compressionQuality: 0.1)
  }

  /// 縦横比を保ったまま、長辺が maxDimension ピクセル以下になるように描き直す
  /// 画面の倍率（3x など）で描くとピクセル数が増えるので scale は 1 に固定する
  static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    let ratio = min(1, maxDimension / max(pixelSize.width, pixelSize.height))
    let targetSize = CGSize(
      width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  /// ファイルサイズを人間が読みやすい形式で表示する
  /// - Parameter bytes: バイト数
  /// - Returns: フォーマットされた文字列
  public static func formatFileSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }

  /// ファイルサイズが制限を超えているかチェックする
  /// - Parameter data: チェックするデータ
  /// - Returns: 制限を超えている場合true
  public static func isFileSizeExceeded(_ data: Data) -> Bool {
    return data.count > maxFileSizeBytes
  }
}
