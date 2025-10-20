import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
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
                Button(action: {
                    Task {
                        await viewModel.toggleLike()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                            .foregroundColor(viewModel.isLiked ? .yellow : .gray)
                        Text("\(viewModel.likeCount)")
                            .foregroundColor(.gray)
                    }
                }
                .disabled(viewModel.isLiking)
                .opacity(viewModel.isLiking ? 0.6 : 1.0)
                .padding()
                
                Button(action: {
                    Task {
                        await viewModel.toggleRepost()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.rectanglepath")
                            .foregroundColor(viewModel.isReposted ? .red : .gray)
                        Text("\(viewModel.repostCount)")
                            .foregroundColor(.gray)
                    }
                }
                .disabled(viewModel.isReposting)
                .opacity(viewModel.isReposting ? 0.6 : 1.0)
                .padding()
            }
            HStack{
                Spacer()
                Text(viewModel.indexedAt)
            }
            
            // リプライ一覧セクション
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                HStack {
                    Text("リプライ (\(viewModel.replies.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("更新", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.fetchReplies()
                        }
                    }
                    .padding(.horizontal)
                }
                
                if viewModel.isFetchingReplies {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                        Spacer()
                    }
                } else if viewModel.replies.isEmpty {
                    Text("リプライを読み込むには更新ボタンを押してください")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                } else {
                    ForEach(viewModel.replies) { reply in
                        ReplyItemView(threadViewPost: reply)
                            .padding(.horizontal)
                    }
                }
            }
        }.padding()
        .onAppear {
            // PostDetailViewが表示された時に初回のリプライを取得
            if viewModel.replies.isEmpty && !viewModel.isFetchingReplies {
                Task {
                    await viewModel.fetchReplies()
                }
            }
        }
    }
}
