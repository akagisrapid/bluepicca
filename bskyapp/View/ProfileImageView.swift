import SwiftUI

struct ProfileImageView: View {
  let viewModel: AsyncImageViewModel
  @State var actor: String
  @State var isProfileView = false
  var body: some View {
    ZStack {
      // サムネ色
      AsyncImage(url: viewModel.url) { image in
        image.image?
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
      }
      .gesture(
        TapGesture().onEnded {
          isProfileView = true
        }
      )

      .sheet(isPresented: $isProfileView) {
        ProfileView(viewModel: .init(actor: actor, profile: .init(did: "", handle: "", labels: [])))
      }
    }
  }
}
