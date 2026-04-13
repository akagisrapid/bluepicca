import SwiftUI

/// URLCacheを利用してメモリ・ディスクキャッシュを持つAsyncImageの代替
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let url else { return }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let img = UIImage(data: cached.data) {
            uiImage = img
            return
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return }
        guard let img = UIImage(data: data) else { return }
        let entry = CachedURLResponse(response: response, data: data)
        URLCache.shared.storeCachedResponse(entry, for: request)
        uiImage = img
    }
}
