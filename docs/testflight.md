# TestFlight でプッシュ通知を確認する

Xcode から実機に入れたビルドは**開発用（sandbox）**の APNs を使う。TestFlight と App Store のビルドは
**本番用（production）**の APNs を使う。本番で届くことは、TestFlight のビルドでしか確かめられない。

アプリは送り先を自動で切り替える（Debug ビルドは sandbox、Release ビルドは production）。
中継サーバーは端末ごとに登録された環境へ送るので、サーバー側の作業はない。

しくみ全体は [push-notifications.md](push-notifications.md)、サーバーの構築は [push-notifications-setup.md](push-notifications-setup.md) を参照。

## 確認に使えるもの

| 場所 | 見えるもの |
|---|---|
| アプリの 設定 → 通知 の下 | 「プッシュ通知を登録済み（本番環境）」などの登録状態。失敗したときはエラーの文言 |
| `https://<サブドメイン>.duckdns.org/health` | `environments.production` に、本番環境で登録された端末の数 |
| サーバーのログ | APNs に送った結果（`APNs 400 ...` などのエラー） |

TestFlight では Xcode のコンソールが見られないため、登録状態を設定画面に出すようにしている。

---

## 1. 事前に確かめること

### PushServerConfig がコミットされているか

TestFlight のビルドはリポジトリの内容から作られる（Xcode Cloud の場合）。`bskyapp/Service/PushRegistrationService.swift` の
`PushServerConfig` が空のままだと、プッシュを使わないビルドになる。手元で入れただけの値は反映されないので、コミットして push しておく。

```swift
static let baseURL = "https://<サブドメイン>.duckdns.org"
static let serviceDid = "did:web:<サブドメイン>.duckdns.org"
```

### APNs キーが本番環境でも使えるか

APNs キーは、作るときに使える環境（Sandbox / Production / 両方）を選べる。Sandbox だけのキーだと、
開発ビルドでは届くのに TestFlight では届かない。

1. [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) で、サーバーに置いたキー（Key ID が `/etc/bluepicca-push/env` の `APNS_KEY_ID` と同じもの）を開く
2. Apple Push Notifications service (APNs) の環境が **Production** を含んでいるか確認する

Sandbox だけだった場合は、Production を含むキーを作り直し、`push-notifications-setup.md` の手順 7 と同じ要領でサーバーのキーと `APNS_KEY_ID` を差し替えて、`deploy.sh` を実行する。

### App ID に Push Notifications が付いているか

[Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list) で `lapipearpopo.bskyapp` を開き、
Capabilities の **Push Notifications** にチェックが入っているか確認する。Xcode から実機で動かしたとき（自動署名）に付いているはず。

---

## 2. TestFlight 用のビルドを作ってアップロードする

方法は 2 つある。普段 Xcode Cloud で配信しているなら A、手元ですぐ試したいなら B。

### A. Xcode Cloud で作る

このリポジトリはすでに Xcode Cloud とつながっている。ワークフローの設定は App Store Connect か Xcode で行う
（リポジトリには入っていない）。

1. Xcode で「Report Navigator（⌘9）」→「Cloud」タブ、または App Store Connect の「Xcode Cloud」を開く
2. ワークフローを開いて「Edit Workflow」
   - **Actions** に「Archive - iOS」があり、Deployment Preparation が「TestFlight (Internal Testing Only)」か「TestFlight and App Store」になっていること
   - **Post-Actions** に「TestFlight Internal Testing」を追加し、配信先のテスターグループを選ぶ
   - グループを選ばずに保存すると「デプロイメントのコンフィグレーションにはテスターが必要です」と出て保存できない。
     先に App Store Connect → TestFlight →「内部テスト」の「＋」でグループを作り、自分をテスターに入れておく
3. ビルドを始める。PR がまだマージされていなければ、ブランチ `claude/nice-heisenberg-mwckva` を指定して手動で始める。次のどれでもよい
   - Xcode のメニュー「Integrate → Xcode Cloud → Start Build」（Xcode 14 以降は Product メニューではなく Integrate メニューにある）
   - Report Navigator（⌘9）の「Cloud」タブで、ワークフローを右クリックして「Start Build」
   - App Store Connect の「Xcode Cloud」タブで、ワークフローを選んで「ビルドを開始」（Mac がなくてもできる）

ビルド番号は Xcode Cloud が自動で増やす。テストのメモは `TestFlight/WhatToTest.ja.txt`（英語は `WhatToTest.en-US.txt`）から自動で入る。

### B. 手元の Xcode からアップロードする

1. Xcode の実行先を「Any iOS Device (arm64)」にする
2. 「Product → Archive」
3. Organizer が開いたら、できたアーカイブを選んで「Distribute App」→「TestFlight Internal Only」→「Distribute」
   - 「Manage Version and Build Number」を有効にすると、ビルド番号を自動で上げてくれる（同じ番号は二度アップロードできない）
4. アップロード後、App Store Connect で処理が終わるまで 10〜30 分ほど待つ

どちらの方法でも、アーカイブは Release 構成で作られるので、アプリは production の APNs に登録する。
署名時に entitlements の `aps-environment` も自動で `production` になる（リポジトリの `development` のままでよい）。

---

## 3. TestFlight で入れて確かめる

1. iPhone の TestFlight アプリから Bluepicca を入れる（Xcode から入れたビルドは置き換わる）
2. Bluepicca を開き、設定 → 通知 →「通知を受け取る」をオンにする。すでにオンなら、アプリを開き直すだけで登録し直す
3. 通知セクションの下の表示を見る

   | 表示 | 意味 |
   |---|---|
   | プッシュ通知を登録済み（本番環境） | 成功。次へ進む |
   | プッシュ通知を登録しています | 端末トークンの発行か登録の途中。数秒待って設定を開き直す |
   | プッシュ通知の登録に失敗しました（…） | 下の「困ったとき」を見る |

4. サーバーにも本番環境で登録されたか確認する。`environments.production` が 1 以上になっていればよい

   ```bash
   curl https://<サブドメイン>.duckdns.org/health
   ```

5. アプリを閉じ、別のアカウントから自分の投稿にリプライしてもらう
6. 数秒以内に「〇〇さんが返信しました」が届けば、本番環境でも動いている

---

## 困ったとき

サーバーのログは次で見られる。

```bash
gcloud compute ssh bluepicca-push --zone=us-east1-b --command='sudo journalctl -u bluepicca-push -n 50 --no-pager'
```

| 症状 | 原因と対処 |
|---|---|
| 設定に何も表示されない | `PushServerConfig` が空のビルド。値をコミットしてビルドし直す |
| 「…（HTTP 401: …）」 | アプリの `serviceDid` とサーバーの `SERVICE_DID` が一致していない |
| 「…aps-environment…」を含むエラー | プロビジョニングに Push Notifications が入っていない。「App ID に Push Notifications が付いているか」を確認してビルドし直す |
| 登録済みなのに届かず、ログに `APNs 403 BadEnvironmentKeyInToken` か `InvalidProviderToken` | APNs キーが本番環境で使えない、または Key ID / Team ID の間違い。「APNs キーが本番環境でも使えるか」を確認する |
| 登録済みなのに届かず、ログに `APNs 400 BadDeviceToken` | 端末の環境と送り先の環境が合っていない。アプリを開き直して登録し直す（設定に「本番環境」と出ることを確認） |
| ログに何も出ない | Jetstream につながっているか（`Jetstream connected`）、リプライが自分の投稿への直接の返信か、送り主をミュートしていないかを確認する |

## 開発ビルドに戻すとき

Xcode から実機に入れ直すと、次に開いたときに sandbox で登録し直す（設定に「開発環境」と出る）。
TestFlight で使っていた端末トークンは、APNs が無効と返した時点でサーバーから自動で消える。
