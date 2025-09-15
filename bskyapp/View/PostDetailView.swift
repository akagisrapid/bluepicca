import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    var body: some View {
        VStack{
            HStack{
                ProfileImageView(viewModel: AsyncImageViewModel(url: viewModel.avatarUrl, imageSize: .avatar, alt: ""), actor: viewModel.post.author?.did ?? "")
                Text(viewModel.displayName).font(.headline)
                Spacer()
            }
            Text(viewModel.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
            // すべてのリンクをexternalLink形式で表示
            ForEach(viewModel.linkCards, id: \.uri) { externalLink in
                LinkCardView(externalLink: externalLink)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            VStack{
                ScrollView{
                    ForEach(viewModel.embeddedImages, id: \.thumb){ embed in
                        let vm = AsyncImageViewModel(
                            url: embed.thumbUrl,
                            imageSize: .thumbnail,
                            alt: embed.alt, fullSizeUrl: embed.fullsizeUrl
                        )
                        AsyncImageView(viewModel: vm)
                    }
                }
            }
            HStack{
                Spacer()
                Button(String(viewModel.post.likeCount ?? 0), systemImage: "star.fill"){
                    // いいね処理
                }
                .padding()
                Button(String(viewModel.post.repostCount ?? 0), systemImage: "arrow.rectanglepath"){
                    // リポスト処理
                }
                .padding()
            }
            HStack{
                Text(viewModel.post.viewer?.repost ?? "")
                Spacer()
                Text(viewModel.indexedAt)
            }
        }.padding()
    }
}
