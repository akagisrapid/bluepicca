import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    @State private var isShowingReplySheet = false
    
    var body: some View {
        VStack(alignment: .leading){
            // リプライ元情報を表示
            if viewModel.isReply {
                NavigationLink(
                    destination: PostDetailView(
                        viewModel: PostDetailViewModel(post: viewModel.parentPost!)
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrowshape.turn.up.left")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text("返信先:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        
                        // リプライ元の投稿プレビュー
                        HStack(alignment: .top, spacing: 12) {
                            ProfileImageView(
                                viewModel: AsyncImageViewModel(
                                    url: viewModel.parentAvatarUrl,
                                    imageSize: .timeline,
                                    alt: viewModel.parentAuthorName
                                ),
                                actor: viewModel.parentAuthorDid
                            )
                            .frame(width: 30, height: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.parentAuthorName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(viewModel.parentText)
                                    .font(.body)
                                    .lineLimit(3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 8)
            }
            
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
                    isShowingReplySheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .foregroundColor(.gray)
                        Text("リプライ")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
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
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleRepliesExpansion()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isRepliesExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.primary)
                            Text("リプライ (\(viewModel.replies.count))")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    if viewModel.isRepliesExpanded {
                        Button("更新", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.fetchReplies()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if viewModel.isRepliesExpanded {
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
                        Text("リプライはありません")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ForEach(viewModel.replies) { reply in
                            NavigationLink(
                                destination: PostDetailView(
                                    viewModel: PostDetailViewModel(post: reply.post)
                                )
                            ) {
                                ReplyItemView(threadViewPost: reply)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }.padding()
        .sheet(isPresented: $isShowingReplySheet) {
            ReplyPostCardView(post: viewModel.post, isShowReplyCard: $isShowingReplySheet)
        }
        .onChange(of: isShowingReplySheet) { isShowing in
            // リプライシートが閉じられた時にリプライ一覧を更新
            if !isShowing {
                Task {
                    await viewModel.refreshRepliesAfterPost()
                }
            }
        }
    }
}
