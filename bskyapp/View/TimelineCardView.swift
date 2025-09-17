import SwiftUI

struct TimelineCardView: View {
    @StateObject var viewModel: TimelineCardViewModel
    var body: some View {
        VStack(alignment: .leading){
            // リポスト情報を表示
            if viewModel.isRepost {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("\(viewModel.repostAuthorName)がリポストしました")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.bottom, 4)
            }
            
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
