import Foundation

class AsyncImageViewModel: ObservableObject{
    @Published var url: URL?
    @Published var imageSize: ImageSize
    init(url: URL?, imageSize: ImageSize) {
        self.url = url
        self.imageSize = imageSize
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
