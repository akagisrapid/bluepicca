import SwiftUI

struct FullScreenImageView: View {
  let images: [EmbedImagesViewItem]
  let initialIndex: Int
  @Environment(\.dismiss) private var dismiss
  @State private var currentIndex: Int
  @State private var pageOffset: CGFloat = 0
  @State private var dismissOffset: CGFloat = 0
  @State private var isAnyImageZoomed: Bool = false
  @State private var dragAxis: DragAxis?

  private enum DragAxis { case horizontal, vertical }

  init(images: [EmbedImagesViewItem], initialIndex: Int = 0) {
    self.images = images
    self.initialIndex = initialIndex
    _currentIndex = State(initialValue: initialIndex)
  }

  private var backgroundOpacity: Double {
    max(0, 1.0 - dismissOffset / 250)
  }

  var body: some View {
    GeometryReader { geo in
      let W = geo.size.width
      let H = geo.size.height
      ZStack {
        Color.black
          .opacity(backgroundOpacity)
          .ignoresSafeArea()

        HStack(spacing: 0) {
          ForEach(Array(images.enumerated()), id: \.element.thumb) { index, image in
            ZoomableImageView(
              url: image.fullsizeUrl ?? image.thumbUrl,
              alt: image.alt,
              isZoomed: $isAnyImageZoomed,
              onDrag: { translation in
                handleDrag(translation)
              },
              onDragEnd: { value in
                handleDragEnd(value)
              },
              onDragCancel: {
                cancelDrag()
              }
            )
            .frame(width: W, height: H)
            .allowsHitTesting(index == currentIndex)
          }
        }
        .offset(x: -CGFloat(currentIndex) * W + pageOffset)

        // ページインジケーター（複数枚のみ表示）
        if images.count > 1 {
          VStack {
            Spacer()
            HStack(spacing: 6) {
              ForEach(Array(images.enumerated()), id: \.element.thumb) { i, _ in
                Circle()
                  .fill(i == currentIndex ? Color.white : Color.white.opacity(0.4))
                  .frame(width: 6, height: 6)
              }
            }
            .padding(.bottom, 12)
          }
        }
      }
      .offset(y: dismissOffset)
    }
    .ignoresSafeArea()
  }

  // MARK: - ジェスチャハンドラ

  private func handleDrag(_ translation: CGSize) {
    let dx = translation.width
    let dy = translation.height
    // 方向はドラッグ開始時に一度だけ決める（毎フレーム判定すると
    // 斜め気味の指の動きでページ送りと dismiss が切り替わりガタつく）
    if dragAxis == nil {
      dragAxis = abs(dx) >= abs(dy) ? .horizontal : .vertical
    }
    switch dragAxis {
    case .horizontal:
      // 端のページでは抵抗感を持たせる
      let atEdge =
        (currentIndex == 0 && dx > 0)
        || (currentIndex == images.count - 1 && dx < 0)
      // ページ送りのアニメーション中に掴み直すと、アニメーションなしの代入で
      // 残りの移動量ぶん一気に飛ぶ。interactiveSpring で今の位置から指に追従させる
      withAnimation(.interactiveSpring()) {
        pageOffset = atEdge ? dx / 3 : dx
      }
    case .vertical:
      // 上方向は抵抗をつけて少しだけ動かす
      dismissOffset = dy > 0 ? dy : dy / 4
    case nil:
      break
    }
  }

  /// ピンチ割り込み等でドラッグが中断されたときに元へ戻す
  private func cancelDrag() {
    dragAxis = nil
    withAnimation(.spring()) {
      pageOffset = 0
      dismissOffset = 0
    }
  }

  private func handleDragEnd(_ value: DragGesture.Value) {
    let dy = value.translation.height
    let predicted = value.predictedEndTranslation
    let axis = dragAxis ?? .horizontal
    dragAxis = nil
    if axis == .horizontal {
      let dx = value.translation.width
      var next = currentIndex
      if dx < -50 || predicted.width < -200 {
        next = min(currentIndex + 1, images.count - 1)
      } else if dx > 50 || predicted.width > 200 {
        next = max(currentIndex - 1, 0)
      }
      withAnimation(.interpolatingSpring(stiffness: 300, damping: 40)) {
        currentIndex = next
        pageOffset = 0
      }
    } else {
      if dy > 120 || predicted.height > 300 {
        dismiss()
      } else {
        withAnimation(.spring()) { dismissOffset = 0 }
      }
    }
  }
}

// MARK: - ピンチズーム対応の単画像ビュー

private struct ZoomableImageView: View {
  let url: URL?
  let alt: String
  @Binding var isZoomed: Bool
  /// scale == 1 のときのドラッグ変位を通知（ページ切り替え・dismiss 用）
  var onDrag: (CGSize) -> Void
  var onDragEnd: (DragGesture.Value) -> Void
  var onDragCancel: () -> Void

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var isPinching: Bool = false

  var body: some View {
    GeometryReader { geo in
      CachedAsyncImage(url: url) { image in
        image.resizable().scaledToFit()
      } placeholder: {
        ProgressView().tint(.white)
      }
      .scaleEffect(scale)
      .offset(offset)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel(alt.isEmpty ? "画像" : alt)
      .gesture(
        SimultaneousGesture(
          MagnificationGesture(minimumScaleDelta: 0.05)
            .onChanged { value in
              isPinching = true
              let proposed = lastScale * value
              if proposed < 1.0 {
                // ラバーバンド：係数を小さくして視覚的縮小を抑える
                scale = 1.0 + (proposed - 1.0) * 0.15
              } else {
                scale = min(proposed, 5.0)
              }
              isZoomed = scale > 1
            }
            .onEnded { _ in
              if scale <= 1.0 {
                withAnimation(.spring()) {
                  scale = 1.0
                  lastScale = 1.0
                  offset = .zero
                  lastOffset = .zero
                }
              } else {
                lastScale = scale
              }
              isZoomed = scale > 1
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPinching = false
              }
            },
          // global 座標で測る：dismiss 中はビュー自体が指と一緒に動くため、
          // ローカル座標だと translation が揺れてガタつく
          DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
              guard !isPinching else { return }
              if scale > 1 {
                // 画像が画面外に出ないようオフセットを制限
                let maxX = geo.size.width * (scale - 1) / 2
                let maxY = geo.size.height * (scale - 1) / 2
                offset = CGSize(
                  width: min(maxX, max(-maxX, lastOffset.width + value.translation.width)),
                  height: min(maxY, max(-maxY, lastOffset.height + value.translation.height))
                )
              } else {
                onDrag(value.translation)
              }
            }
            .onEnded { value in
              guard !isPinching else {
                onDragCancel()
                return
              }
              if scale > 1 {
                lastOffset = offset
              } else {
                onDragEnd(value)
              }
            }
        )
      )
      .onTapGesture(count: 2) {
        withAnimation(.spring()) {
          if scale > 1 {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
            isZoomed = false
          } else {
            scale = 2
            lastScale = 2
            isZoomed = true
          }
        }
      }
    }
  }
}
