import SwiftUI

struct FullScreenImageView: View {
    let images: [EmbedImagesViewItem]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var pageOffset: CGFloat = 0      // 左右ページ移動オフセット
    @State private var dismissOffset: CGFloat = 0   // 下スワイプ dismiss オフセット
    @State private var isAnyImageZoomed: Bool = false

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

                // ページを HStack で横並びにし、offset で表示位置を制御
                HStack(spacing: 0) {
                    ForEach(images.indices, id: \.self) { index in
                        ZoomableImageView(
                            url: images[index].fullsizeUrl ?? images[index].thumbUrl,
                            alt: images[index].alt,
                            isZoomed: $isAnyImageZoomed
                        )
                        .frame(width: W, height: H)
                    }
                }
                .offset(x: -CGFloat(currentIndex) * W + pageOffset)
                // ページ切り替え + dismiss を一つの DragGesture で処理
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isAnyImageZoomed else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            if abs(dx) >= abs(dy) {
                                // 端のページを超えようとしたときの抵抗感
                                let atEdge = (currentIndex == 0 && dx > 0)
                                    || (currentIndex == images.count - 1 && dx < 0)
                                pageOffset = atEdge ? dx / 3 : dx
                            } else if dy > 0 {
                                dismissOffset = dy
                            }
                        }
                        .onEnded { value in
                            guard !isAnyImageZoomed else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let predicted = value.predictedEndTranslation
                            if abs(dx) >= abs(dy) {
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
                )

                // ページインジケーター（複数枚のみ表示）
                if images.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(images.indices, id: \.self) { i in
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
}

// MARK: - ピンチズーム対応の単画像ビュー

private struct ZoomableImageView: View {
    let url: URL?
    let alt: String
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            ProgressView().tint(.white)
        }
        .scaleEffect(scale)
        .offset(offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(alt.isEmpty ? "画像" : alt)
        // .simultaneousGesture を使い、親の DragGesture（ページ切り替え）と共存
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1.0, min(lastScale * value, 5.0))
                    isZoomed = scale > 1
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale < 1 {
                        withAnimation(.spring()) {
                            scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                        }
                    }
                    isZoomed = scale > 1
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard scale > 1 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    guard scale > 1 else { return }
                    lastOffset = offset
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                if scale > 1 {
                    scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                    isZoomed = false
                } else {
                    scale = 2; lastScale = 2
                    isZoomed = true
                }
            }
        }
    }
}
