import SwiftUI

/// URLCache（ディスク）+ ImageCache（インメモリUIImage）の2段キャッシュを持つAsyncImage代替
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
  let url: URL?
  let content: (Image) -> Content
  let placeholder: () -> Placeholder

  @State private var uiImage: UIImage?

  init(
    url: URL?, @ViewBuilder content: @escaping (Image) -> Content,
    @ViewBuilder placeholder: @escaping () -> Placeholder
  ) {
    self.url = url
    self.content = content
    self.placeholder = placeholder
    // インメモリキャッシュにあれば即座に表示（プレースホルダー不要）
    _uiImage = State(initialValue: url.flatMap { ImageCache.shared[$0] })
  }

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
    if let cached = ImageCache.shared[url] {
      uiImage = cached
      return
    }
    let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
    if let cached = URLCache.shared.cachedResponse(for: request),
      let img = UIImage(data: cached.data)
    {
      ImageCache.shared[url] = img
      uiImage = img
      return
    }
    guard let (data, response) = try? await URLSession.shared.data(for: request) else { return }
    guard let img = UIImage(data: data) else { return }
    URLCache.shared.storeCachedResponse(
      CachedURLResponse(response: response, data: data), for: request)
    ImageCache.shared[url] = img
    uiImage = img
  }
}
