# プッシュ通知の設定一覧

プッシュ通知を動かすために、どのサービスのどこに何を設定したかの記録（2026 年 10 月 31 日時点）。
設定を変えるとき、別の環境に作り直すとき、何かが動かなくなったときに見る。

しくみは [push-notifications.md](push-notifications.md)、構築の手順は [push-notifications-setup.md](push-notifications-setup.md)、
TestFlight での確認は [testflight.md](testflight.md) を参照。

秘密の値（APNs キーの中身、DuckDNS の token、請求先アカウント）はここに書かない。`<...>` は手元で確認する値。

## 一致していないと動かない値

複数の場所に同じ値を書いている。片方だけ変えると動かなくなる。

| 値 | 書いてある場所 | ずれたときの症状 |
|---|---|---|
| `did:web:bluepicca-push.duckdns.org` | アプリの `PushServerConfig.serviceDid`、VM の `/etc/bluepicca-push/env` の `SERVICE_DID` | 登録が `HTTP 401` で断られる |
| `bluepicca-push.duckdns.org` | アプリの `PushServerConfig.baseURL`、DuckDNS のサブドメイン、Caddy の設定（`SERVICE_DID` から自動で作る） | アプリがサーバーにつながらない、HTTPS の証明書が取れない |
| `lapipearpopo.bskyapp`（バンドル ID） | Xcode の `PRODUCT_BUNDLE_IDENTIFIER`、サーバーの `APNS_TOPIC`（既定値） | `APNs 400 DeviceTokenNotForTopic` |
| APNs キーの Key ID | VM の `env` の `APNS_KEY_ID`、VM の `AuthKey.p8`（同じキーのもの） | `APNs 403 InvalidProviderToken` |
| `lapipearpopo.bskyapp.push.register` / `.unregister` | アプリの `PushRegistrationService`、サーバーの `server/src/http.ts` | 登録が `HTTP 401` か `404` |
| `lapipearpopo.bskyapp.notificationRefresh` | `bskyapp/Info.plist` の `BGTaskSchedulerPermittedIdentifiers`、`LocalNotificationService.refreshTaskIdentifier` | 端末内の定期確認（予備の方式）がバックグラウンドで動かない |

---

## Apple Developer

| 項目 | 設定 | 備考 |
|---|---|---|
| Team ID | `TPXR4FNVUK` | Membership ページで確認できる |
| App ID `lapipearpopo.bskyapp` | Capabilities の **Push Notifications** を有効 | Xcode の自動署名で、実機に入れたときに付いた |
| APNs キー（使用中） | Environment：**Sandbox & Production**、Key ID：`<新しい Key ID>` | .p8 は VM の `/etc/bluepicca-push/AuthKey.p8` と手元の安全な場所にある |
| APNs キー（旧） | Environment：Sandbox のみ | TestFlight で `403 BadEnvironmentKeyInToken` になったため差し替えた。**Revoke（失効）する** |

APNs キーの Environment は作ったあとに変えられない。作り直すときは最初から「Sandbox & Production」を選ぶ。

## App Store Connect

| 項目 | 設定 | 備考 |
|---|---|---|
| TestFlight の内部テストグループ | `<グループ名>`（自分をテスターに追加） | Xcode Cloud の TestFlight 配信にはグループが必須 |
| Xcode Cloud のワークフロー | `Default`：Archive（iOS）＋ Post-Action「TestFlight Internal Testing」（上のグループ） | ビルドの手動開始の方法が見つからず、今回は使っていない |
| 配信したビルド | 1.2 を手元の Xcode から Archive してアップロード（TestFlight Internal Only） | 1.1 は承認済みで新しいビルドを受け付けないため 1.2 に上げた |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（ビルド設定） | 毎回の質問に答えなくて済む |
| App のプライバシー | **未更新** | ユーザ ID（DID）、その他のユーザコンテンツ（ミュートワード）などの申告を足す |

## Google Cloud

| 項目 | 設定 | 備考 |
|---|---|---|
| プロジェクト | `<プロジェクト ID>` | 請求先アカウントをリンク済み（無料枠でも必須） |
| API | Compute Engine API を有効 | `gcloud services enable compute.googleapis.com` |
| 予算アラート | 月 `<金額>` | 課金が始まったらメールで気づける。課金を止めはしない |
| VM | `bluepicca-push`・e2-micro・`us-east1-b`・Debian 13・標準永続ディスク（pd-standard）30GB・ネットワークタグ `bluepicca-push` | すべて無料枠の条件。ディスクを「バランス」にすると有料 |
| 外部 IP | エフェメラル（固定 IP ではない） | 停止・起動で変わることがあるが、DuckDNS の自動更新で追従する。無料枠の対象外で課金される可能性があるので請求レポートで確認する |
| ファイアウォール | `bluepicca-push-web`：tcp 80・443 を、タグ `bluepicca-push` の VM に許可 | 80 は Caddy の証明書取得に使う |

作成は `server/deploy/gce/create-vm.sh`、更新は `server/deploy/gce/deploy.sh`。

## DuckDNS

| 項目 | 設定 | 備考 |
|---|---|---|
| サブドメイン | `bluepicca-push`（`bluepicca-push.duckdns.org`） | アプリに組み込んでいるので変えるとアプリの更新が要る |
| token | VM の `/etc/bluepicca-push/duckdns.env` | DuckDNS のパスワードと同じ扱い |
| IP の更新 | VM の `duckdns.timer` が 5 分ごとに今の IP を送る | |

## VM の中

| 場所 | 中身 |
|---|---|
| `/etc/bluepicca-push/env` | `SERVICE_DID=did:web:bluepicca-push.duckdns.org`、`APNS_KEY_PATH=/etc/bluepicca-push/AuthKey.p8`、`APNS_KEY_ID=<新しい Key ID>`、`APNS_TEAM_ID=TPXR4FNVUK`、`HOST=127.0.0.1`、`PORT=8080` |
| `/etc/bluepicca-push/AuthKey.p8` | Sandbox & Production の APNs キー。所有者 `root:bluepicca`、権限 `640` |
| `/etc/bluepicca-push/duckdns.env` | `DUCKDNS_SUBDOMAIN=bluepicca-push`、`DUCKDNS_TOKEN=<token>` |
| `/opt/bluepicca-push` | サーバー本体。`deploy.sh` のたびに入れ替わる |
| `/var/lib/bluepicca-push/bluepicca-push.sqlite` | 登録された端末と Jetstream の cursor |
| `/etc/systemd/system/bluepicca-push.service` | サーバーを `bluepicca` ユーザーで常時起動 |
| `/etc/systemd/system/duckdns.service` / `.timer` | DuckDNS の IP 更新 |
| `/etc/caddy/Caddyfile` | `bluepicca-push.duckdns.org` の HTTPS を `127.0.0.1:8080` に中継 |
| `/opt/node`（`/usr/local/bin/node`） | Node.js 26.13.0（`server/.node-version` の版） |
| `/swapfile` | 1GB のスワップ（e2-micro のメモリ不足対策） |

`env` や `AuthKey.p8` を変えたときは `sudo systemctl restart bluepicca-push`。コードを変えたときは手元から `deploy.sh`。

## アプリ（リポジトリ）

| 場所 | 設定 | 備考 |
|---|---|---|
| `bskyapp/Service/PushRegistrationService.swift` の `PushServerConfig` | `baseURL = "https://bluepicca-push.duckdns.org"`、`serviceDid = "did:web:bluepicca-push.duckdns.org"` | 空にすると、プッシュを使わず端末内の定期確認だけになる |
| 同ファイルの APNs 環境 | Debug ビルドは `sandbox`、Release ビルド（TestFlight・App Store）は `production` | `#if DEBUG` で自動で切り替える |
| `bskyapp/bskyapp.entitlements` | `aps-environment = development` | 配信用に署名するとき Xcode が自動で `production` にする。書き換えなくてよい |
| `project.pbxproj` の `CODE_SIGN_ENTITLEMENTS` | `bskyapp/bskyapp.entitlements` | |
| `project.pbxproj` の `membershipExceptions` | `bskyapp.entitlements`、`Info.plist` などを含める | **外すとアプリに余計なファイルが入る。** Xcode の自動書き換えで消えたことがある（下の「つまずいた点」） |
| `project.pbxproj` の `INFOPLIST_FILE` | `bskyapp/Info.plist` | 自動生成の Info.plist と合わせて使う |
| `bskyapp/Info.plist` | `BGTaskSchedulerPermittedIdentifiers`、`UIBackgroundModes = fetch` | 端末内の定期確認（予備）のバックグラウンド更新 |
| `project.pbxproj` の `MARKETING_VERSION` | `1.2` | |
| Keychain | 資格情報を `kSecAttrAccessibleAfterFirstUnlock` で保存 | 画面ロック中のバックグラウンド処理でもログインできるように |
| `TestFlight/WhatToTest.ja.txt` / `.en-US.txt` | TestFlight のテスト内容 | Xcode Cloud でビルドしたときに使われる |
| `docs/privacy-policy.html` | 通知サーバーに送る情報・保存場所・Apple への送信・削除のタイミングを追記 | 公開されるのは main にマージしたとき |

## 手元の Mac

| 項目 | 設定 |
|---|---|
| Node.js | anyenv の nodenv で 26.13.0。`server/.node-version` を読んで自動で切り替わる |
| gcloud | Homebrew の `google-cloud-sdk`。`gcloud init` でログインとプロジェクト選択済み |
| SSH 鍵 | 初回の `gcloud compute ssh` で作成（`~/.ssh/google_compute_engine`） |
| Claude の Remote Control | `~/bskyapp` を追加済み。ただしクラウドのセッションからはまだ接続できない |

## GitHub

| 項目 | 設定 |
|---|---|
| `.github/workflows/server.yml` | `server/` を変えた PR で、型チェックとテストを実行する |
| `.gitignore` | `*.p8`、`*.p12`、`*.mobileprovision`、`.env`、`duckdns.env` を除外（ルートと `server/`） |

---

## つまずいた点と対処

| 起きたこと | 原因 | 対処 |
|---|---|---|
| TestFlight だけ通知が届かず、ログに `APNs 403 BadEnvironmentKeyInToken` | APNs キーの Environment が Sandbox だけだった（あとから変えられない） | Sandbox & Production のキーを作り直し、VM の `AuthKey.p8` と `APNS_KEY_ID` を差し替えて再起動 |
| TestFlight へのアップロードが「CFBundleShortVersionString [1.1] … must contain a higher version」で失敗 | 1.1 は App Store で承認済みで、新しいビルドを受け付けない | `MARKETING_VERSION` を 1.2 に上げた |
| Xcode Cloud のワークフローが「デプロイメントのコンフィグレーションにはテスターが必要です」で保存できない | Post-Action の TestFlight 配信先グループが未選択 | App Store Connect で内部テストグループを作って自分を入れ、ワークフローで選んだ |
| Xcode Cloud のビルドの始め方が見つからない | Xcode 14 以降はメニューが Product から Integrate に移っている。App Store Connect でもボタンが見つからなかった | 手元の Xcode から Archive → Distribute App → TestFlight Internal Only でアップロードした |
| pull したら手元の変更で止まり、合流で `project.pbxproj` がコンフリクト | Xcode が `project.pbxproj` を自動で書き換えていた（`bskyapp.entitlements` の除外が消え、削除済みの plist が戻り、形式も変わっていた） | 手元をリモートと同じ状態に戻した（`git reset --hard origin/<ブランチ>`）。**Xcode の自動書き換えはコミットせず `git checkout -- bskyapp.xcodeproj/project.pbxproj` で捨てる** |
| `.nvmrc` で指定した Node の版が使われない | nodenv は `.nvmrc` ではなく `.node-version` を読む | `server/.node-version` に変えた（CI も同じファイルを読む） |
| anyenv の nodenv で 26.13.0 が一覧に出ない | node-build（インストールできる版の一覧）が古かった | `anyenv update`（または node-build を `git pull`） |
| Remote Control に追加したフォルダにクラウドから接続できない | Mac 側が理由を返さない（アプリの更新・再起動でも変わらず） | 未解決。手元のターミナルで作業した |

## まだやっていないこと

- [ ] 旧 APNs キー（Sandbox のみ）を Revoke する
- [ ] App Store Connect の「App のプライバシー」を更新する
- [ ] PR [akagisrapid/bluepicca#136](https://github.com/akagisrapid/bluepicca/pull/136) をマージする（プライバシーポリシーの公開もこのとき）
- [ ] 削除した `GoogleService-Info.plist` の Firebase API キーを Google Cloud コンソールで削除する（任意）
- [ ] Xcode Cloud のビルドを始められるようにする（任意。手元からのアップロードで代わりになる）
