import UIKit

final class ImageCache {
  static let shared = ImageCache()
  private let cache = NSCache<NSString, UIImage>()

  private init() {
    cache.countLimit = 500
    // コストは展開後のビットマップのバイト数（実際のメモリ使用量）で数える。
    // 以前の JPEG サイズ基準より 1 枚あたりの値が大きくなるので上限も広げる。
    // メモリが逼迫したときは NSCache が自動で捨てる
    cache.totalCostLimit = 200 * 1024 * 1024
  }

  /// 画像が占めるメモリのバイト数。JPEG に変換し直すと大きな画像では
  /// メインスレッドが数十ミリ秒止まるため、ビットマップの寸法から計算する
  static func cost(of image: UIImage) -> Int {
    if let cgImage = image.cgImage {
      return cgImage.bytesPerRow * cgImage.height
    }
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    return Int(pixelWidth * pixelHeight * 4)
  }

  subscript(url: URL) -> UIImage? {
    get { cache.object(forKey: url.absoluteString as NSString) }
    set {
      if let image = newValue {
        let cost = Self.cost(of: image)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
      } else {
        cache.removeObject(forKey: url.absoluteString as NSString)
      }
    }
  }
}
