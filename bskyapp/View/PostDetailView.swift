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
//                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.embeddedImages, id: \.thumb){
                        embed in
                        let vm = AsyncImageViewModel(
                                url: embed.thumbUrl,
                                imageSize: .thumbnail, 
                                fullSizeUrl: embed.fullsizeUrl)
                        AsyncImageView(viewModel: vm)
                    }
//                }
            }
            
            Text(viewModel.indexedAt)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
        }
    }
}
