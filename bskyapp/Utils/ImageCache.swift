import UIKit

final class ImageCache {
  static let shared = ImageCache()
  private let cache = NSCache<NSString, UIImage>()

  private init() {
    cache.countLimit = 500
    cache.totalCostLimit = 80 * 1024 * 1024
  }

  subscript(url: URL) -> UIImage? {
    get { cache.object(forKey: url.absoluteString as NSString) }
    set {
      if let image = newValue {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
      } else {
        cache.removeObject(forKey: url.absoluteString as NSString)
      }
    }
  }
}
