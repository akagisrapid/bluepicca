import SwiftUI

private struct ProfileNavigationKey: EnvironmentKey {
  static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
  var navigateToProfile: (String) -> Void {
    get { self[ProfileNavigationKey.self] }
    set { self[ProfileNavigationKey.self] = newValue }
  }
}

struct ProfileImageView: View {
  let viewModel: AsyncImageViewModel
  let actor: String
  @Environment(\.navigateToProfile) private var navigateToProfile
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
      navigateToProfile(actor)
    } label: {
      CachedAsyncImage(url: viewModel.url) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: scaledMaxSize, maxHeight: scaledMaxSize)
      } placeholder: {
        Circle()
          .fill(Color(.systemGray5))
          .frame(width: scaledMaxSize, height: scaledMaxSize)
      }
    }
    .buttonStyle(.plain)
    .fixedSize()
  }
}
