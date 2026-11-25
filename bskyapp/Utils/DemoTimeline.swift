#if DEBUG
  import Foundation

  /// 起動引数 `-demoTimeline` を付けると、ログインせずに固定の投稿で TL を表示する（DEBUG ビルドのみ）。
  /// 自分のアカウントの TL に頼らず、長い本文や画像の枚数・比率ごとのレイアウトを確かめるためのもの。
  /// 画像は data: URL の単色 PNG なので、通信なしで表示できる。
  enum DemoTimeline {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demoTimeline")

    static func response() throws -> FeedResponse {
      let data = try JSONSerialization.data(withJSONObject: ["feed": items])
      return try JSONDecoder().decode(FeedResponse.self, from: data)
    }

    private static let blue =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGNwa7oDRAwQCgArpgaRxc+2BQAAAABJRU5ErkJggg=="
    private static let green =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGMI2FIBRAwQCgAo/gXxqc7iWgAAAABJRU5ErkJggg=="
    private static let orange =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP4MM0GiBggFAA0FgcJXimokwAAAABJRU5ErkJggg=="
    private static let pink =
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGN4lrcAiBggFAA31gfRcwmFBAAAAABJRU5ErkJggg=="

    private static let longText = """
      長い本文の折り返し確認用の投稿です。一行に収まらない長さの文章が、画面の幅に合わせて正しく折り返されるかを見ます。
      改行を含む段落も入れています。

      二段落目。iPhone Duo を開いたときと閉じたとき、分割表示で幅が狭くなったときに、文字がはみ出したり途中で切れたりしないことを確かめてください。
      三段落目。最後の行までちゃんと表示されていれば OK です。#デモ #折り返し
      """

    private static var items: [[String: Any]] {
      [
        ["post": post(1, text: longText, minutesAgo: 1)],
        [
          "post": post(
            2,
            text:
              "区切りのない長い英単語と URL: Supercalifragilisticexpialidocious_and_even_longer_identifier https://example.com/a/very/long/path/that/does/not/break/naturally?query=parameters&and=more",
            minutesAgo: 3)
        ],
        ["post": post(3, text: "横長の画像 1 枚（2:1）", minutesAgo: 5, images: [(blue, 2, 1)])],
        ["post": post(4, text: "縦長の画像 1 枚（1:2、高さの上限で切れる）", minutesAgo: 8, images: [(green, 1, 2)])],
        ["post": post(5, text: "画像 2 枚", minutesAgo: 12, images: [(orange, 4, 3), (pink, 3, 4)])],
        [
          "post": post(
            6, text: "画像 3 枚", minutesAgo: 20,
            images: [(blue, 1, 1), (green, 16, 9), (orange, 9, 16)])
        ],
        [
          "post": post(
            7, text: longText, minutesAgo: 30,
            images: [(pink, 1, 1), (blue, 1, 1), (green, 1, 1), (orange, 1, 1)])
        ],
        [
          "post": post(8, text: "リポストされた投稿 #デモ", minutesAgo: 60),
          "reason": [
            "$type": "app.bsky.feed.defs#reasonRepost",
            "by": author(99), "indexedAt": timestamp(minutesAgo: 2),
          ],
        ],
      ]
    }

    private static func author(_ n: Int) -> [String: Any] {
      ["did": "did:plc:demo\(n)", "handle": "demo\(n).bsky.social", "displayName": "デモユーザー \(n)"]
    }

    private static func timestamp(minutesAgo: Int) -> String {
      ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(minutesAgo) * 60))
    }

    private static func post(
      _ n: Int, text: String, minutesAgo: Int, images: [(String, Int, Int)] = []
    ) -> [String: Any] {
      var post: [String: Any] = [
        "uri": "at://did:plc:demo\(n)/app.bsky.feed.post/demo\(n)",
        "cid": "demo-cid-\(n)",
        "author": author(n),
        "record": [
          "$type": "app.bsky.feed.post", "text": text,
          "createdAt": timestamp(minutesAgo: minutesAgo),
        ],
        "replyCount": 0, "repostCount": 0, "likeCount": 0,
        "indexedAt": timestamp(minutesAgo: minutesAgo),
      ]
      if !images.isEmpty {
        post["embed"] = [
          "$type": "app.bsky.embed.images#view",
          "images": images.map { url, width, height in
            [
              "thumb": url, "fullsize": url, "alt": "",
              "aspectRatio": ["width": width, "height": height],
            ]
          },
        ]
      }
      return post
    }
  }
#endif
