import SwiftUI

struct TimelineCardView: View {
    @StateObject var viewModel: TimelineCardViewModel
    var body: some View {
        HStack{
            AsyncImageView(viewModel: AsyncImageViewModel(url: viewModel.post.author.avatarUrl, imageSize: .avatar, alt: ""))
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
