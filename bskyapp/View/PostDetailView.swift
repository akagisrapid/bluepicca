import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    var body: some View {
        VStack{
            HStack{
                AsyncImageView(viewModel: AsyncImageViewModel(url: viewModel.avatarUrl, imageSize: .avatar))
                Text(viewModel.displayName).font(.headline)
                Spacer()
            }
            Text(viewModel.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            VStack{
                ForEach(viewModel.embeddedImages, id: \.thumb){
                    embed in
                    AsyncImageView(viewModel: AsyncImageViewModel(url: embed.thumbUrl, imageSize: .thumbnail))
                }
            }
            
            Text(viewModel.indexedAt)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
        }
    }
}
