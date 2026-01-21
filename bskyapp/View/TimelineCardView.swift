import SwiftUI

struct TimelineCardView: View {
  let viewModel: TimelineCardViewModel
  @ObservedObject var post: Post

  @State private var isLiking = false
  @State private var isReposting = false

  init(viewModel: TimelineCardViewModel) {
    self.viewModel = viewModel
    self._post = ObservedObject(wrappedValue: viewModel.post)
  }

  var body: some View {
    VStack(alignment: .leading) {
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

      HStack {
        ProfileImageView(
          viewModel: AsyncImageViewModel(
            url: viewModel.post.author?.avatarUrl, imageSize: .timeline, alt: ""),
          actor: viewModel.post.author?.did ?? "")
        Text(viewModel.authorName).font(.headline)
        Spacer()
        Text(viewModel.postedTimeRelative)
          .dynamicTypeSize(.xSmall)
          .foregroundColor(.gray)
      }
      VStack(alignment: .leading) {
        Text(viewModel.text)
      }

      // いいね・リポストボタン
      HStack(spacing: 20) {
        // いいねボタン
        Button(action: {
          Task {
            isLiking = true
            await viewModel.toggleLike()
            isLiking = false
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
        .disabled(isLiking)
        .opacity(isLiking ? 0.6 : 1.0)

        // リポストボタン
        Button(action: {
          Task {
            isReposting = true
            await viewModel.toggleRepost()
            isReposting = false
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
        .disabled(isReposting)
        .opacity(isReposting ? 0.6 : 1.0)

        Spacer()
      }
      .padding(.top, 8)
    }.padding()
  }
}
