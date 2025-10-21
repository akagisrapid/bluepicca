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
            
            // リプライ情報を表示
            if viewModel.isReply {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("\(viewModel.replyTargetAuthorName)への返信")
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
            
            // いいね・リポストボタン
            HStack(spacing: 20) {
                // いいねボタン
                Button(action: {
                    Task {
                        await viewModel.toggleLike()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                            .foregroundColor(viewModel.isLiked ? .yellow : .gray)
                        Text("\(viewModel.likeCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .disabled(viewModel.isLiking)
                .opacity(viewModel.isLiking ? 0.6 : 1.0)
                
                // リポストボタン
                Button(action: {
                    Task {
                        await viewModel.toggleRepost()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.rectanglepath")
                            .foregroundColor(viewModel.isReposted ? .red : .gray)
                        Text("\(viewModel.repostCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .disabled(viewModel.isReposting)
                .opacity(viewModel.isReposting ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(.top, 8)
        }.padding()
    }
}
