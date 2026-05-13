import SwiftUI

struct ProfileImageView: View {
  let viewModel: AsyncImageViewModel
  let actor: String
  @State private var navigateToProfile = false

  var body: some View {
    Button {
      navigateToProfile = true
    } label: {
      AsyncImage(url: viewModel.url) { image in
        image.image?
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
      }
    }
    .buttonStyle(.plain)
    .background(
      NavigationLink(
        isActive: $navigateToProfile,
        destination: {
          ProfileView(
            viewModel: ProfileViewModel(
              actor: actor,
              profile: .init(did: "", handle: "", labels: [])
            )
          )
        },
        label: { EmptyView() }
      )
      .hidden()
    )
  }
}
