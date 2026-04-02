import SwiftUI

struct FullScreenImageView: View {
    let images: [EmbedImagesViewItem]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(images: [EmbedImagesViewItem], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImageView(
                        url: images[index].fullsizeUrl ?? images[index].thumbUrl,
                        alt: images[index].alt
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

            // 閉じるボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5).clipShape(Circle()))
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
    }
}

// MARK: - ピンチズーム対応の単画像ビュー

private struct ZoomableImageView: View {
    let url: URL?
    let alt: String
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
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1.0, min(lastScale * value, 5.0))
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1 {
                            withAnimation(.spring()) { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                        }
                    },
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                else { scale = 2; lastScale = 2 }
            }
        }
    }
}
