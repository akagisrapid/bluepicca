# Bluepicca

SwiftUI で作っているネイティブの iOS 向け Bluesky クライアント。
AT Protocol を直接呼び出し、外部ライブラリには依存しない。

## 主な機能

- ホーム TL・カスタムフィード・ハッシュタグフィードの閲覧
- 投稿・返信・引用、画像の添付（下書き保存あり）
- いいね・リポスト（楽観的更新、スワイプ操作の割り当てを変更可能）
- スレッド表示、プロフィール、フォロー / フォロワー一覧
- 検索、ブックマーク、通知
- キーワード / ユーザーのミュート、ブロック、通報、コンテンツラベルの設定
- プッシュ通知（自前の中継サーバー経由。未設定時はローカル通知でのポーリング）

## 動作環境

- iOS 17 以降
- Xcode（最新の安定版）

## ビルド

```bash
open bskyapp.xcodeproj
```

Xcode で `bskyapp` スキームを選んで ⌘R。ログインには Bluesky のハンドルと[アプリパスワード](https://bsky.app/settings/app-passwords)を使う。

コマンドラインでビルドする場合:

```bash
xcodebuild -project bskyapp.xcodeproj -scheme bskyapp -destination 'generic/platform=iOS Simulator' build
```

## テスト

`bskyappTests/` に Swift Testing の単体テストがある。テストは日本語の文言を確かめるので、言語と地域を指定して動かす。

```bash
xcrun simctl list devices available | grep iPhone
xcodebuild test -project bskyapp.xcodeproj -scheme bskyapp -destination 'platform=iOS Simulator,id=<UDID>' -testLanguage ja -testRegion JP
```

## ディレクトリ構成

| パス | 内容 |
|---|---|
| `bskyapp/` | アプリ本体（View / ViewModel / Service / Model / Session / Utils） |
| `bskyappTests/` | 単体テスト |
| `server/` | プッシュ通知の中継サーバー（TypeScript / Node.js）。[server/README.md](server/README.md) |
| `docs/` | 設計メモ・運用手順・[プライバシーポリシー](docs/privacy-policy.html) |
| `TestFlight/` | TestFlight の「テスト内容」の文面 |
| `.github/workflows/` | CI（iOS のビルドとテスト、サーバーのテスト、Claude Code） |

設計の概要は [CLAUDE.md](CLAUDE.md) を参照。

## ドキュメント

- [プッシュ通知のしくみ](docs/push-notifications.md) / [構築手順](docs/push-notifications-setup.md) / [設定一覧](docs/push-notifications-settings.md)
- [TestFlight での確認手順](docs/testflight.md)
- [パワーユーザー向け TL ロードマップ](docs/power-user-tl-roadmap.md)
