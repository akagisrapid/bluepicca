import Foundation

final class AsyncImageViewModel: ObservableObject {
  let url: URL?
  let imageSize: ImageSize
  let alt: String
  let fullSizeUrl: URL?

  init(url: URL?, imageSize: ImageSize, alt: String, fullSizeUrl: URL? = nil) {
    self.url = url
    self.alt = alt
    self.fullSizeUrl = fullSizeUrl
    self.imageSize = imageSize
  }
}

extension AsyncImageViewModel {
}

enum ImageSize {
  case timeline
  case avatar
  case thumbnail
}

extension ImageSize {
  var maxWidth: CGFloat {
    switch self {
    case .timeline:
      return 30
    case .avatar:
      return 60
    case .thumbnail:
      return 250
    }
  }
  var maxHeight: CGFloat {
    switch self {
    case .avatar:
      return 60
    case .thumbnail:
      return 250
    case .timeline:
      return 30
    }
  }
}

