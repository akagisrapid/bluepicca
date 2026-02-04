import SwiftUI

struct TimelineCardView: View {
  let viewModel: TimelineCardViewModel
  @ObservedObject var post: Post

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
        VStack(alignment: .trailing, spacing: 2) {
          Text(viewModel.postedTimeRelative)
            .dynamicTypeSize(.xSmall)
            .foregroundColor(.gray)

          // いいね・リポスト数表示
          HStack(spacing: 8) {
            HStack(spacing: 2) {
              Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                .foregroundColor(viewModel.isLiked ? .yellow : .gray)
                .font(.caption2)
              Text("\(viewModel.likeCount)")
                .font(.caption2)
                .foregroundColor(.gray)
            }

            HStack(spacing: 2) {
              Image(systemName: "arrow.rectanglepath")
                .foregroundColor(viewModel.isReposted ? .red : .gray)
                .font(.caption2)
              Text("\(viewModel.repostCount)")
                .font(.caption2)
                .foregroundColor(.gray)
            }
          }
        }
      }

      VStack(alignment: .leading) {
        Text(viewModel.text)
      }

      // 添付情報（画像枚数・動画・リンクURL）
      if viewModel.imageCount > 0 || viewModel.videoCount > 0 || viewModel.externalUrl != nil {
        HStack(spacing: 8) {
          if viewModel.imageCount > 0 {
            Text("🖼️x\(viewModel.imageCount)")
              .font(.caption)
              .foregroundColor(.gray)
          }
          if viewModel.videoCount > 0 {
            Text("🎬x\(viewModel.videoCount)")
              .font(.caption)
              .foregroundColor(.gray)
          }
          if let url = viewModel.externalUrl {
            Text("🔗 \(url)")
              .font(.caption)
              .foregroundColor(.blue)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
      }
    }.padding(.horizontal).padding(.vertical, 6)
  }
}
