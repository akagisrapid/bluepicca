import SwiftUI

extension EmbedImagesViewItem {
  /// 表示用にクランプしたアスペクト比（幅 / 高さ）。不正値は 16:9 にフォールバック。
  var displayAspectRatio: CGFloat {
    guard let ar = aspectRatio, ar.width > 0, ar.height > 0 else { return 16.0 / 9.0 }
    return min(max(CGFloat(ar.width) / CGFloat(ar.height), 0.5), 3.0)
  }
}

/// 投稿の添付画像グリッド（1〜4枚）。
///
/// タイムライン（`.thumbnail`）と投稿詳細（`.full`）で画質・高さ・角丸だけが異なるため、
/// レイアウトを1箇所に集約する。タップ後のフルスクリーン表示は呼び出し側が `onTap` で受ける。
struct PostImageGrid: View {
  enum Quality {
    case thumbnail  // タイムライン用（サムネイル・コンパクト）
    case full  // 投稿詳細用（フルサイズ・大きめ）
  }

  let images: [EmbedImagesViewItem]
  var quality: Quality = .thumbnail
  let onTap: (Int) -> Void

  private var displayImages: [EmbedImagesViewItem] { Array(images.prefix(4)) }
  private var count: Int { displayImages.count }
  private var cornerRadius: CGFloat { quality == .full ? 10 : 8 }
  private var innerSpacing: CGFloat { quality == .full ? 3 : 2 }

  private func url(for image: EmbedImagesViewItem) -> URL? {
    quality == .full ? image.fullsizeUrl : image.thumbUrl
  }

  private func gridHeight(width: CGFloat) -> CGFloat {
    let singleCap: CGFloat = quality == .full ? 400 : 300
    switch count {
    case 1: return min(width / displayImages[0].displayAspectRatio, singleCap)
    case 2, 3: return quality == .full ? 220 : 160
    default: return quality == .full ? 280 : 200
    }
  }

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      layout
        .frame(width: w, height: gridHeight(width: w))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    .frame(
      maxWidth: .infinity,
      minHeight: gridHeight(width: UIScreen.main.bounds.width - 32))
  }

  @ViewBuilder
  private var layout: some View {
    switch count {
    case 1:
      tile(0)
    case 2:
      HStack(spacing: innerSpacing) {
        tile(0)
        tile(1)
      }
    case 3:
      HStack(spacing: innerSpacing) {
        tile(0)
        VStack(spacing: innerSpacing) {
          tile(1)
          tile(2)
        }
      }
    default:
      VStack(spacing: innerSpacing) {
        HStack(spacing: innerSpacing) {
          tile(0)
          tile(1)
        }
        HStack(spacing: innerSpacing) {
          tile(2)
          tile(3)
        }
      }
    }
  }

  @ViewBuilder
  private func tile(_ index: Int) -> some View {
    Button {
      onTap(index)
    } label: {
      CachedAsyncImage(url: url(for: displayImages[index])) { image in
        image.resizable().scaledToFill()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    }
    .buttonStyle(.plain)
  }
}
