import SwiftUI

struct ProfileImageView: View {
  let viewModel: AsyncImageViewModel
  var body: some View {
    AsyncImage(url: viewModel.url) { image in
      image.image?
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
    }
  }
}
