import SwiftUI

struct ProfileImageView: View {
  let viewModel: AsyncImageViewModel
  let actor: String
  @State private var navigateToProfile = false
  @ScaledMetric(relativeTo: .subheadline) private var timelineSize: CGFloat = 30
  @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 60

  private var scaledMaxSize: CGFloat {
    switch viewModel.imageSize {
    case .timeline: return timelineSize
    case .avatar: return avatarSize
    case .thumbnail: return viewModel.imageSize.maxWidth
    }
  }

  var body: some View {
    Button {
      navigateToProfile = true
    } label: {
      AsyncImage(url: viewModel.url) { image in
        image.image?
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: scaledMaxSize, maxHeight: scaledMaxSize)
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
