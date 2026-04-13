import Foundation
import Alamofire

struct GetUserFeedsApi {
    /// ユーザーの保存済みフィード（ピン済み・未ピン）を FeedTab 配列で返す。
    /// ホームTL（FeedTab.home）は先頭に追加される。
    func getUserFeeds() async throws -> [FeedTab] {
        let session = try await SessionManager.shared.getSession()
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(session.accessJwt)"
        ]

        // Step 1: getPreferences でフィードURIリストを取得
        let prefsUrl = "https://bsky.social/xrpc/app.bsky.actor.getPreferences"
        let prefsResponse = await AF.request(prefsUrl, method: .get, headers: headers)
            .validate()
            .serializingDecodable(GetPreferencesResponse.self).response

        guard case .success(let prefs) = prefsResponse.result else {
            throw prefsResponse.error ?? URLError(.badServerResponse)
        }

        // savedFeedsPrefV2 の items から type == "feed" のURIを抽出
        let feedUris = prefs.preferences
            .compactMap { $0.items }
            .flatMap { $0 }
            .filter { $0.type == "feed" }
            .map { $0.value }

        guard !feedUris.isEmpty else {
            return [.home]
        }

        // Step 2: getFeedGenerators で表示名・アバターを取得
        // クエリパラメータは repeated key: feeds=at://...&feeds=at://...
        var components = URLComponents(string: "https://bsky.social/xrpc/app.bsky.feed.getFeedGenerators")!
        components.queryItems = feedUris.map { URLQueryItem(name: "feeds", value: $0) }

        guard let generatorsUrl = components.url else {
            return [.home]
        }

        let generatorsResponse = await AF.request(generatorsUrl, method: .get, headers: headers)
            .validate()
            .serializingDecodable(GetFeedGeneratorsResponse.self).response

        guard case .success(let generators) = generatorsResponse.result else {
            // getFeedGenerators が失敗してもホームタブだけ返す
            return [.home]
        }

        // feedUris の順序を維持しながら FeedTab を構築
        let generatorMap = Dictionary(uniqueKeysWithValues: generators.feeds.map { ($0.uri, $0) })
        let tabs: [FeedTab] = feedUris.compactMap { uri in
            guard let gen = generatorMap[uri] else { return nil }
            return FeedTab(
                id: uri,
                name: gen.displayName,
                uri: uri,
                avatarUrl: gen.avatar.flatMap { URL(string: $0) }
            )
        }

        return [.home] + tabs
    }
}
