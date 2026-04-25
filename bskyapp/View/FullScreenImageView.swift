import SwiftUI

struct FullScreenImageView: View {
    let images: [EmbedImagesViewItem]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var dismissOffset: CGSize = .zero

    init(images: [EmbedImagesViewItem], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    private var backgroundOpacity: Double {
        max(0, 1.0 - dismissOffset.height / 250)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImageView(
                        url: images[index].fullsizeUrl ?? images[index].thumbUrl,
                        alt: images[index].alt,
                        dismissOffset: $dismissOffset,
                        onDismiss: { dismiss() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

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
        .offset(y: dismissOffset.height)
    }
}

// MARK: - ピンチズーム対応の単画像ビュー

private struct ZoomableImageView: View {
    let url: URL?
    let alt: String
    @Binding var dismissOffset: CGSize
    var onDismiss: () -> Void
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
        .accessibilityLabel(alt.isEmpty ? "画像" : alt)
        // .simultaneousGesture を使うことで TabView のページスワイプと共存させる
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1.0, min(lastScale * value, 5.0))
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale < 1 {
                        withAnimation(.spring()) { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if scale > 1 {
                        // ズーム中はパン操作
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    } else {
                        // 下スワイプのみ dismiss に使用（横スワイプは TabView に任せる）
                        let dy = value.translation.height
                        let dx = value.translation.width
                        if dy > 0 && dy > abs(dx) {
                            dismissOffset = CGSize(width: 0, height: dy)
                        }
                    }
                }
                .onEnded { value in
                    if scale > 1 {
                        lastOffset = offset
                    } else {
                        let dy = value.translation.height
                        let predictedDy = value.predictedEndTranslation.height
                        if dy > 120 || predictedDy > 300 {
                            onDismiss()
                        } else {
                            withAnimation(.spring()) { dismissOffset = .zero }
                        }
                    }
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                else { scale = 2; lastScale = 2 }
            }
        }
    }
}
