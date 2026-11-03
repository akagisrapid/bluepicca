import Testing
import UIKit

@testable import bskyapp

/// ImageCache のコストは展開後のビットマップのバイト数で数える。
/// JPEG に変換し直して測るとメインスレッドが止まるため
struct ImageCacheTests {
  private func makeImage(width: Int, height: Int, scale: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: width, height: height), format: format)
    return renderer.image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
  }

  @Test func costIsBitmapBytes() throws {
    let image = makeImage(width: 100, height: 50, scale: 1)
    let cgImage = try #require(image.cgImage)
    #expect(ImageCache.cost(of: image) == cgImage.bytesPerRow * cgImage.height)
    // 1 ピクセル 4 バイト以上（行の詰め物があるので ≥）
    #expect(ImageCache.cost(of: image) >= 100 * 50 * 4)
  }

  @Test func costCountsScale() {
    let oneX = ImageCache.cost(of: makeImage(width: 100, height: 50, scale: 1))
    let twoX = ImageCache.cost(of: makeImage(width: 100, height: 50, scale: 2))
    // 同じ論理サイズでも 2x は 200x100 ピクセルぶんのメモリを使う
    #expect(twoX >= 200 * 100 * 4)
    #expect(twoX > oneX * 3)
  }
}
