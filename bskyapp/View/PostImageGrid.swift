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

  var body: some View {
    gridBox
      .overlay { layout }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }

  /// グリッドの外枠。割り当てられた幅から最初のレイアウトで高さが決まるので、
  /// 画面幅に頼らず、測り終えるまで高さ0になることもない（分割表示・折りたたみ端末対応）。
  @ViewBuilder
  private var gridBox: some View {
    if count == 1 {
      // 1枚: 幅いっぱいで画像の比率どおり、ただし高さは上限まで
      Color.clear
        .aspectRatio(displayImages[0].displayAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: quality == .full ? 400 : 300)
    } else {
      Color.clear
        .frame(maxWidth: .infinity)
        .frame(height: count <= 3 ? (quality == .full ? 220 : 160) : (quality == .full ? 280 : 200))
    }
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
