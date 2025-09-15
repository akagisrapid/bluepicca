import SwiftUI

struct TimelineCardView: View {
    @StateObject var viewModel: TimelineCardViewModel
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                ProfileImageView(viewModel: AsyncImageViewModel(url: viewModel.post.author?.avatarUrl, imageSize: .timeline, alt: ""), actor: viewModel.post.author?.did ?? "")
                Text(viewModel.authorName).font(.headline)
                Spacer()
                Text(viewModel.postedTimeRelative)
                    .dynamicTypeSize(.xSmall)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading){
                Text(viewModel.text)
            }
        }.padding()
    }
}
