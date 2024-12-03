import SwiftUI

struct TimelineCardView: View {
    @StateObject var viewModel: TimelineCardViewModel
    var body: some View {
        HStack{
            ProfileImageView(viewModel: AsyncImageViewModel(url: viewModel.post.author.avatarUrl, imageSize: .avatar, alt: ""), actor: viewModel.post.author.did)
            VStack(alignment: .leading){
                Text(viewModel.authorName).font(.headline)
                Text(viewModel.text)
                HStack{
                    Spacer()
                    Text(viewModel.postedTimeRelative)
                        .dynamicTypeSize(.xSmall)
                }
            }
            .padding()
        }
        .padding(2)
    }
}
