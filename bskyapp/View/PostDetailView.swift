import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    var body: some View {
        VStack{
            HStack{
                AsyncImageView(viewModel: AsyncImageViewModel(url: viewModel.avatarUrl, imageSize: .avatar, alt: ""))
                Text(viewModel.displayName).font(.headline)
                Spacer()
            }
            Text(viewModel.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            VStack{
                ForEach(viewModel.embeddedImages, id: \.thumb){ embed in
                    let vm = AsyncImageViewModel(
                        url: embed.thumbUrl,
                        imageSize: .thumbnail,
                        alt: embed.alt, fullSizeUrl: embed.fullsizeUrl
                    )
                    AsyncImageView(viewModel: vm)
                }
            }
            
            Text(viewModel.indexedAt)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
            Spacer()
        }.padding()
    }
}
