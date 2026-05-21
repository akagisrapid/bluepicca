import Foundation
import UIKit

public class ImageCompressionHelper {
  // ファイルサイズ制限（976.56KB）
  public static let maxFileSizeBytes: Int = 1_000_000  // 約976.56KB

  /// 画像を指定されたファイルサイズ以下に圧縮する
  /// - Parameters:
  ///   - image: 圧縮する画像
  ///   - maxSizeBytes: 最大ファイルサイズ（バイト）
  /// - Returns: 圧縮された画像データ
  public static func compressImage(_ image: UIImage, maxSizeBytes: Int = maxFileSizeBytes) -> Data?
  {
    // 最初に画像のサイズを調整（大きすぎる場合）
    let resizedImage = resizeImageIfNeeded(image)

    // 圧縮品質を段階的に下げながら試行
    let compressionQualities: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]

    for quality in compressionQualities {
      if let compressedData = resizedImage.jpegData(compressionQuality: quality) {
        dlog("圧縮品質 \(quality): \(compressedData.count)バイト")

        if compressedData.count <= maxSizeBytes {
          dlog("圧縮成功: \(compressedData.count)バイト (品質: \(quality))")
          return compressedData
        }
      }
    }

    // 品質を下げても制限を超える場合、画像サイズをさらに小さくして再試行
    let smallerImage = resizeImage(resizedImage, targetSize: CGSize(width: 800, height: 600))

    for quality in compressionQualities {
      if let compressedData = smallerImage.jpegData(compressionQuality: quality) {
        dlog("小さいサイズで圧縮品質 \(quality): \(compressedData.count)バイト")

        if compressedData.count <= maxSizeBytes {
          dlog("小さいサイズで圧縮成功: \(compressedData.count)バイト (品質: \(quality))")
          return compressedData
        }
      }
    }

    // さらに小さくして最終試行
    let verySmallImage = resizeImage(resizedImage, targetSize: CGSize(width: 600, height: 450))

    for quality in compressionQualities {
      if let compressedData = verySmallImage.jpegData(compressionQuality: quality) {
        dlog("とても小さいサイズで圧縮品質 \(quality): \(compressedData.count)バイト")

        if compressedData.count <= maxSizeBytes {
          dlog("とても小さいサイズで圧縮成功: \(compressedData.count)バイト (品質: \(quality))")
          return compressedData
        }
      }
    }

    // 最後の手段として最低品質で返す
    dlog("警告: ファイルサイズ制限内に収まりませんでした")
    return verySmallImage.jpegData(compressionQuality: 0.1)
  }

  /// 画像が大きすぎる場合にリサイズする
  /// - Parameter image: リサイズする画像
  /// - Returns: リサイズされた画像
  private static func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
    let maxDimension: CGFloat = 1920  // 最大幅・高さ
    let size = image.size

    // 画像が既に小さい場合はそのまま返す
    if size.width <= maxDimension && size.height <= maxDimension {
      return image
    }

    // アスペクト比を保持してリサイズ
    let scale = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)

    return resizeImage(image, targetSize: newSize)
  }

  /// 画像を指定されたサイズにリサイズする
  /// - Parameters:
  ///   - image: リサイズする画像
  ///   - targetSize: 目標サイズ
  /// - Returns: リサイズされた画像
  private static func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: targetSize)

    return renderer.image { _ in
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
