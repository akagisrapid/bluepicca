import Foundation
import SwiftUI

struct TextSegment: Identifiable {
    let id = UUID()
    let text: String
    let hashtag: String?
}

class PostDetailViewModel: ObservableObject {
  @Published var post: Post
  @Published var reason: Reason?
  @Published var parentPost: Post?
  @Published var isReposting: Bool = false
  @Published var isLiking: Bool = false
  @Published var replies: [ThreadViewPost] = []
  @Published var isFetchingReplies: Bool = false
  @Published var isRepliesExpanded: Bool = false
  @Published var selectedHashtag: String?
  @Published var isShowingHashtagSheet: Bool = false
  var likesResponse: GetLikesApiResponse = .init(uri: "", likes: [])

  init(post: Post, reason: Reason? = nil) {
    self.post = post
    self.reason = reason

    // 永続化された状態を復元
    PostInteractionHelper.restorePersistedStates(for: post)
    Task {
      if let uri = post.uri {
        do {
          let response = try await GetLikesApi().getLikes(param: .init(uri: uri, cid: post.cid))

          await MainActor.run {
            self.likesResponse = response
          }
        } catch {
          print("Failed to fetch likes: \(error)")
        }

        do {
          let threadResponse = try await GetPostThreadApi().getPostThread(uri: uri)

          await MainActor.run {
            if let parent = threadResponse.thread.parent {
              self.parentPost = parent.value.post
            }
          }
        } catch {
          print("Failed to fetch thread info: \(error)")
        }
      }
    }
  }
  var avatarUrl: URL? {
    post.author?.avatarUrl
  }
  var displayName: String {
    post.author?.displayName ?? ""
  }
  var text: String {
    return post.record?.text ?? ""
  }

  var textSegments: [TextSegment] {
    guard let facets = post.record?.facets else {
      return [TextSegment(text: text, hashtag: nil)]
    }

    let utf8Bytes = Array(text.utf8)
    var hashtagRanges: [(byteStart: Int, byteEnd: Int, tag: String)] = []

    for facet in facets {
      guard let index = facet.index, let features = facet.features else { continue }
      for feature in features {
        if let tag = feature.tag {
          hashtagRanges.append((index.byteStart, index.byteEnd, tag))
        }
      }
    }

    hashtagRanges.sort { $0.byteStart < $1.byteStart }

    if hashtagRanges.isEmpty {
      return [TextSegment(text: text, hashtag: nil)]
    }

    var segments: [TextSegment] = []
    var currentByte = 0

    for range in hashtagRanges {
      let start = max(range.byteStart, 0)
      let end = min(range.byteEnd, utf8Bytes.count)
      guard start >= currentByte, end <= utf8Bytes.count else { continue }

      if currentByte < start {
        let slice = Array(utf8Bytes[currentByte..<start])
        if let str = String(bytes: slice, encoding: .utf8) {
          segments.append(TextSegment(text: str, hashtag: nil))
        }
      }

      let tagSlice = Array(utf8Bytes[start..<end])
      if let tagText = String(bytes: tagSlice, encoding: .utf8) {
        segments.append(TextSegment(text: tagText, hashtag: range.tag))
      }

      currentByte = end
    }

    if currentByte < utf8Bytes.count {
      let slice = Array(utf8Bytes[currentByte..<utf8Bytes.count])
      if let str = String(bytes: slice, encoding: .utf8) {
        segments.append(TextSegment(text: str, hashtag: nil))
      }
    }

    return segments
  }

  var hashtagAttributedText: AttributedString {
    var result = AttributedString()
    for segment in textSegments {
      var attr = AttributedString(segment.text)
      if let tag = segment.hashtag,
         let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
        attr.foregroundColor = .blue
        attr.link = URL(string: "hashtag://\(encoded)")
      }
      result.append(attr)
    }
    return result
  }

  var textWithLinks: AttributedString {
    let uri = post.record?.facets?.first?.features?.first?.uri
    return uri?.detectLinks() ?? AttributedString(text)
  }

  var externalLink: EmbeddedExternalViewItem? {
    return post.embed?.external
  }

  var hasExternalLink: Bool {
    return externalLink != nil
  }

  var linkCards: [EmbeddedExternalViewItem] {
    var cards: [EmbeddedExternalViewItem] = []

    if let external = post.embed?.external {
      cards.append(external)
    }

    if let facets = post.record?.facets {
      for facet in facets {
        if let features = facet.features {
          for feature in features {
            if let uri = feature.uri, !uri.isEmpty {
              let alreadyExists = cards.contains { $0.uri == uri }
              if !alreadyExists {
                let externalItem = createExternalViewItem(from: uri)
                cards.append(externalItem)
              }
            }
          }
        }
      }
    }

    return cards
  }

  private func createExternalViewItem(from uri: String) -> EmbeddedExternalViewItem {
    var title = uri
    if let url = URL(string: uri), let host = url.host {
      title = host
    }

    return EmbeddedExternalViewItem(
      uri: uri,
      title: title,
      description: "リンク先のコンテンツ",
      thumb: nil
    )
  }
  var indexedAt: String {
    guard let indexedAt = post.indexedAt, let date = indexedAt.parseToDateRemovingMilliseconds
    else {
      return ""
    }
    return date.formatted(.dateTime.hour().minute())
  }
  var embeddedImages: [EmbedImagesViewItem] {
    guard let images = post.embed?.images else {
      return []
    }
    return images
  }

  var embeddedVideo: EmbedVideoViewItem? {
    return post.embed?.video
  }

  // リポスト情報関連のプロパティ
  var isRepost: Bool {
    return reason != nil
  }

  var repostAuthorName: String {
    return reason?.by.displayName ?? reason?.by.handle ?? ""
  }

  var repostAuthorHandle: String {
    return reason?.by.handle ?? ""
  }

  // MARK: - いいね機能

  var isLiked: Bool {
    return post.viewer?.like != nil
  }

  var likeCount: Int {
    return post.likeCount ?? 0
  }

  @MainActor
  func toggleLike() async {
    isLiking = true
    await PostInteractionHelper.toggleLike(post: post)
    isLiking = false
  }

  // MARK: - リポスト機能

  var isReposted: Bool {
    return post.viewer?.repost != nil
  }

  var repostCount: Int {
    return post.repostCount ?? 0
  }

  @MainActor
  func toggleRepost() async {
    isReposting = true
    await PostInteractionHelper.toggleRepost(post: post)
    isReposting = false
  }

  // MARK: - リプライ機能

  @MainActor
  func toggleRepliesExpansion() {
    isRepliesExpanded.toggle()

    if isRepliesExpanded && replies.isEmpty && !isFetchingReplies {
      Task {
        await fetchReplies()
      }
    }
  }

  @MainActor
  func fetchReplies() async {
    guard let postUri = post.uri else { return }

    isFetchingReplies = true

    do {
      let response =
        try await GetPostThreadApi().getPostThread(uri: postUri)

      replies = response.thread.replies ?? []

      if let parent = response.thread.parent {
        parentPost = parent.value.post
      }
    } catch {
      print("リプライ取得エラー: \(error)")
    }

    isFetchingReplies = false
  }

  @MainActor
  func refreshRepliesAfterPost() async {
    if isRepliesExpanded {
      await fetchReplies()
    }
  }

  // MARK: - リプライ元情報関連のプロパティ

  var isReply: Bool {
    return parentPost != nil
  }

  var parentAuthorName: String {
    return parentPost?.author?.displayName ?? parentPost?.author?.handle ?? ""
  }

  var parentText: String {
    return parentPost?.record?.text ?? ""
  }

  var parentAvatarUrl: URL? {
    return parentPost?.author?.avatarUrl
  }

  var parentAuthorDid: String {
    return parentPost?.author?.did ?? ""
  }
}
