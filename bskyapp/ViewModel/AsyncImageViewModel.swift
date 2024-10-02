import Foundation

class AsyncImageViewModel: ObservableObject{
    @Published var url: URL?
    @Published var imageSize: ImageSize
    @Published var alt: String
    @Published var fullSizeUrl: URL?
    @Published var tapToOpen: TapToOpen?
    init(url: URL?, imageSize: ImageSize, alt: String, fullSizeUrl: URL? = nil, tapToOpen: TapToOpen? = nil) {
        self.url = url
        self.alt = alt
        self.fullSizeUrl = fullSizeUrl
        self.imageSize = imageSize
        self.tapToOpen = tapToOpen
    }
}

extension AsyncImageViewModel{
}


enum ImageSize{
    case avatar
    case thumbnail
}

enum TapToOpen{
    case profile
    case fullSize
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
