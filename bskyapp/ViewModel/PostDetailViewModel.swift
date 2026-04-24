import Foundation
import SwiftUI

class PostDetailViewModel: ObservableObject {
    @Published var post: Post
    @Published var reason: Reason?
    @Published var parentChain: [Post] = []   // oldest → newest 順
    @Published var replies: [ThreadViewPost] = []
    @Published var isLoadingThread: Bool = false
    @Published var isReposting: Bool = false
    @Published var isLiking: Bool = false

    init(post: Post, reason: Reason? = nil) {
        self.post = post
        self.reason = reason
        PostInteractionHelper.restorePersistedStates(for: post)
        Task { await fetchThread() }
    }

    @MainActor
    func fetchThread() async {
        guard let uri = post.uri else { return }
        isLoadingThread = true
        do {
            let response = try await GetPostThreadApi().getPostThread(uri: uri)
            post = response.thread.post
            replies = response.thread.replies ?? []
            parentChain = extractParentChain(from: response.thread)
        } catch {
            print("Thread fetch error: \(error)")
        }
        isLoadingThread = false
    }

    @MainActor
    func refreshAfterReply() async {
        await fetchThread()
    }

    private func extractParentChain(from thread: ThreadViewPost) -> [Post] {
        var chain: [Post] = []
        var current = thread.parent?.value
        while let node = current {
            chain.append(node.post)
            current = node.parent?.value
        }
        return chain.reversed()
    }

    // MARK: - 表示プロパティ

    var avatarUrl: URL? { post.author?.avatarUrl }
    var displayName: String { post.author?.displayName ?? "" }
    var text: String { post.record?.text ?? "" }
    var quotedPost: EmbeddedRecordViewItem? { post.embed?.record }
    var embeddedImages: [EmbedImagesViewItem] { post.embed?.resolvedImages ?? [] }
    var embeddedVideo: EmbedVideoViewItem? { post.embed?.video }

    var linkCards: [EmbeddedExternalViewItem] {
        var cards: [EmbeddedExternalViewItem] = []
        if let external = post.embed?.resolvedExternal { cards.append(external) }
        for facet in post.record?.facets ?? [] {
            for feature in facet.features ?? [] {
                if let uri = feature.uri, !uri.isEmpty, !cards.contains(where: { $0.uri == uri }) {
                    cards.append(makeExternalViewItem(uri: uri))
                }
            }
        }
        return cards
    }

    private func makeExternalViewItem(uri: String) -> EmbeddedExternalViewItem {
        let title = URL(string: uri)?.host ?? uri
        return EmbeddedExternalViewItem(uri: uri, title: title, description: "リンク先のコンテンツ", thumb: nil)
    }

    var indexedAt: String {
        guard let raw = post.indexedAt,
              let date = raw.parseToDateRemovingMilliseconds else { return "" }
        return date.formatted(.dateTime.year().month().day().hour().minute())
    }

    var isRepost: Bool { reason != nil }
    var repostAuthorName: String { reason?.by?.displayName ?? reason?.by?.handle ?? "" }

    var isLiked: Bool { post.viewer?.like != nil }
    var likeCount: Int { post.likeCount ?? 0 }
    var isReposted: Bool { post.viewer?.repost != nil }
    var repostCount: Int { post.repostCount ?? 0 }

    // MARK: - インタラクション

    @MainActor
    func toggleLike() async {
        isLiking = true
        await PostInteractionHelper.toggleLike(post: post)
        isLiking = false
    }

    @MainActor
    func toggleRepost() async {
        isReposting = true
        await PostInteractionHelper.toggleRepost(post: post)
        isReposting = false
    }
}
