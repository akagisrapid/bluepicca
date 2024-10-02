import Foundation

class AsyncImageViewModel: ObservableObject{
    @Published var url: URL?
    @Published var imageSize: ImageSize
    @Published var alt: String
    @Published var fullSizeUrl: URL?
    init(url: URL?, imageSize: ImageSize, alt: String, fullSizeUrl: URL? = nil) {
        self.url = url
        self.alt = alt
        self.fullSizeUrl = fullSizeUrl
        self.imageSize = imageSize
    }
}

extension AsyncImageViewModel{
}


enum ImageSize{
    case avatar
    case thumbnail
}

extension ImageSize{
    var maxWidth: CGFloat{
        switch self {
        case .avatar:
            return 60
        case .thumbnail:
            return 250
        }
    }
    var maxHeight: CGFloat{
        switch self {
        case .avatar:
            return 60
        case .thumbnail:
            return 250
        }
    }
}
