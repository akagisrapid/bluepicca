import SwiftUI

struct AsyncImageView: View {
    @StateObject var viewModel: AsyncImageViewModel
    var body: some View {
        AsyncImage(url: viewModel.url){ image in
            image.image?.resizable().frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
        }
    }
}
