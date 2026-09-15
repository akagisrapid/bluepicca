import SwiftUI

// MARK: - 添付メディアバッジ（ピル形状）

struct MediaBadge: View {
  let icon: String
  let label: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption2)
      Text(label)
        .font(.caption2)
    }
    .foregroundColor(.secondary)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color(.systemGray6))
    .clipShape(Capsule())
  }
}

// MARK: - 引用ポストカード

struct QuotePostCard: View {
  let quoted: EmbeddedRecordViewItem
  @AppStorage("hideImagePreview") private var hideImagePreview: Bool = false

  private var quotedAsPost: Post {
    Post(uri: quoted.uri, cid: nil, author: quoted.author, record: quoted.value)
  }

  private var quotedImages: [EmbedImagesViewItem] {
    quoted.embeds?.compactMap { $0.images }.first ?? []
  }

  var body: some View {
    if quoted.isFeedGenerator {
      FeedGeneratorCard(quoted: quoted)
    } else {
      NavigationLink(
        destination: PostDetailView(viewModel: PostDetailViewModel(post: quotedAsPost))
      ) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            CachedAsyncImage(url: quoted.author?.avatarUrl) { image in
              image.resizable()
            } placeholder: {
              Circle().fill(Color(.systemGray5))
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())

            Text(quoted.author?.displayName ?? quoted.author?.handle ?? "")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
              .lineLimit(1)

            Text("@\(quoted.author?.handle ?? "")")
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          if let text = quoted.value?.text, !text.isEmpty {
            Text(text)
              .font(.caption)
              .foregroundColor(.primary)
              .lineLimit(4)
          }

          if !quotedImages.isEmpty {
            if hideImagePreview {
              MediaBadge(
                icon: "photo",
                label: quotedImages.count == 1 ? "画像" : "画像 \(quotedImages.count)枚")
            } else {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                  ForEach(quotedImages.prefix(4), id: \.thumb) { image in
                    CachedAsyncImage(url: image.thumbUrl) { img in
                      img.resizable().scaledToFill()
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                  }
                }
              }
            }
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - フィードジェネレーターカード

private struct FeedGeneratorCard: View {
  let quoted: EmbeddedRecordViewItem

  var body: some View {
    NavigationLink(
      destination: FeedGeneratorTimelineView(
        feedUri: quoted.uri ?? "",
        feedName: quoted.displayName ?? "フィード"
      )
    ) {
      cardContent
    }
    .buttonStyle(.plain)
  }

  private var cardContent: some View {
    HStack(spacing: 10) {
      CachedAsyncImage(url: quoted.avatarUrl) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
          .overlay(Image(systemName: "list.star").font(.caption).foregroundColor(.secondary))
      }
      .frame(width: 36, height: 36)
      .clipShape(RoundedRectangle(cornerRadius: 6))

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Image(systemName: "list.star")
            .font(.caption2)
            .foregroundColor(.secondary)
          Text("フィード")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        Text(quoted.displayName ?? "")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
          .lineLimit(1)
        if let description = quoted.description, !description.isEmpty {
          Text(description)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
        if let creator = quoted.creator {
          Text("by \(creator.displayName ?? creator.handle ?? "")")
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(.systemGray4), lineWidth: 0.5)
    )
  }
}

// MARK: - タイムライン用コンパクトリンクカード

struct CompactLinkCard: View {
  let externalLink: EmbeddedExternalViewItem

  var body: some View {
    if let destination = URL(string: externalLink.uri) {
      Link(destination: destination) {
        HStack(spacing: 10) {
          Image(systemName: "link")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 16)

          VStack(alignment: .leading, spacing: 1) {
            Text(externalLink.title.isEmpty ? displayHost : externalLink.title)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.primary)
              .lineLimit(1)
            if !externalLink.description.isEmpty {
              Text(externalLink.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
            Text(displayHost)
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
  }

  private var displayHost: String {
    guard let url = URL(string: externalLink.uri), let host = url.host else {
      return externalLink.uri
    }
    return host
  }
}
