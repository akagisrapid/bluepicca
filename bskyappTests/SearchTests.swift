import Foundation
import Testing

@testable import bskyapp

/// 検索の種類の決め方。"#" はハッシュタグ（投稿）、"@" はユーザー、それ以外は選んだ種類
struct SearchScopeTests {
  private func viewModel(_ query: String, scope: SearchScope = .posts) -> SearchViewModel {
    let vm = SearchViewModel(initialQuery: query)
    vm.scope = scope
    return vm
  }

  @Test func plainQueryUsesSelectedScope() {
    #expect(viewModel("alice", scope: .posts).effectiveScope == .posts)
    #expect(viewModel("alice", scope: .users).effectiveScope == .users)
  }

  @Test func hashtagAlwaysSearchesPosts() {
    #expect(viewModel("#bluesky", scope: .users).effectiveScope == .posts)
    #expect(viewModel("  #bluesky", scope: .users).isHashtagQuery)
  }

  @Test func atSignSearchesUsers() {
    #expect(viewModel("@alice", scope: .posts).effectiveScope == .users)
  }

  @Test func actorQueryDropsAtSign() {
    #expect(SearchViewModel.actorQuery("@alice.bsky.social") == "alice.bsky.social")
    #expect(SearchViewModel.actorQuery("  alice ") == "alice")
    #expect(SearchViewModel.actorQuery("@") == "")
  }

  @Test func hasResultsFollowsEffectiveScope() {
    let vm = viewModel("alice", scope: .users)
    vm.posts = [Post(uri: "u", cid: nil, author: nil, record: nil, labels: nil)]
    #expect(!vm.hasResults)
    vm.scope = .posts
    #expect(vm.hasResults)
  }
}

/// app.bsky.actor.searchActors の応答。displayName・avatar・viewer が無い人もいる
struct SearchActorsDecodingTests {
  @Test func decodesActorsWithOptionalFields() throws {
    let json = #"""
      {
        "cursor": "50",
        "actors": [
          {
            "did": "did:plc:abc", "handle": "alice.bsky.social", "displayName": "Alice",
            "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:abc/x@jpeg",
            "description": "hello", "indexedAt": "2026-10-01T00:00:00.000Z",
            "viewer": {"muted": false, "following": "at://did:plc:me/app.bsky.graph.follow/1"},
            "labels": []
          },
          {"did": "did:plc:def", "handle": "bob.bsky.social"}
        ]
      }
      """#
    let response = try JSONDecoder().decode(SearchActorsResponse.self, from: Data(json.utf8))
    #expect(response.cursor == "50")
    #expect(response.actors.count == 2)
    #expect(response.actors[0].displayName == "Alice")
    #expect(response.actors[0].viewer?.following != nil)
    #expect(response.actors[1].displayName == nil)
    #expect(response.actors[1].viewer == nil)
  }
}
