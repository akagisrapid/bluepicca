import Foundation

class AsyncImageViewModel: ObservableObject{
    @Published var url: URL?
    @Published var fullSizeUrl: URL?
    @Published var imageSize: ImageSize
    init(url: URL?, imageSize: ImageSize, fullSizeUrl: URL? = nil) {
        self.url = url
        self.fullSizeUrl = fullSizeUrl
        self.imageSize = imageSize
    }
}

extension AsyncImageViewModel{
    var zoomedUrl: URL?{
        fullSizeUrl ?? url
    }
}


enum ImageSize{
    case avatar
    case thumbnail
}

extension ImageSize{
    var maxWidth: CGFloat{
        switch self {
        case .avatar:
            return 40
        case .thumbnail:
            return 100
        }
    }
    var maxHeight: CGFloat{
        switch self {
        case .avatar:
            return 40
        case .thumbnail:
            return 100
        }
    }
}
