# プッシュ通知のしくみと設定まとめ

Bluepicca に通知機能を入れたときの設計と、本番で動かすまでに行った設定の記録。
秘密の値（APNs キー、DuckDNS の token など）はここに書かず、`<...>` で示す。

## なぜ自前のサーバーが要るのか

- iOS のプッシュは Apple の APNs を通して送る。送るには、そのアプリの開発者アカウントで作った APNs キーが要る
- Bluesky のプッシュ配信は公式アプリの鍵しか持っていないため、Bluepicca 宛てには送れない（規約ではなく仕組みの制約）
- そこで、Bluesky の公開データ（Jetstream）を見て、Bluepicca 宛ての APNs プッシュに変換する中継サーバーを自分で動かす

## 全体の構成

```
[Bluesky Jetstream] ──(投稿・いいね・リポスト・フォロー)──▶ [中継サーバー] ──(APNs)──▶ [Bluepicca]
                                                              ▲
[Bluepicca] ──(端末トークン・通知する種類・ミュート設定 + service auth JWT)──┘
```

| 部分 | 場所 | 役割 |
|---|---|---|
| アプリの通知設定 | `bskyapp/Utils/NotificationSettings.swift` | 通知のオン・オフと種類（返信・メンション・引用・いいね・リポスト・フォロー）を保存 |
| 設定画面 | `bskyapp/View/SettingsView.swift`（「通知」セクション） | 上の設定の UI。オンにすると通知の許可を求める |
| プッシュ登録 | `bskyapp/Service/PushRegistrationService.swift` | APNs の端末トークンと設定をサーバーに登録・解除する。接続先は `PushServerConfig` |
| 端末内の定期確認 | `bskyapp/Service/LocalNotificationService.swift` | サーバー未設定時の予備。listNotifications を起動中 2 分ごと＋バックグラウンド更新で確認する。プッシュが有効な間は止まる |
| 中継サーバー | `server/`（TypeScript・Node 26） | Jetstream を監視して APNs に送る。詳細は `server/README.md` |
| 本番の配置 | `server/deploy/gce/` | Google Cloud の無料枠で動かすスクリプトと手順。詳細は `server/deploy/gce/README.md` |

### 本人確認

アプリはアプリパスワードやアクセストークンをサーバーに渡さない。登録のたびに自分の PDS の
`com.atproto.server.getServiceAuth` で短命の JWT（`aud` = サーバーの DID、`lxm` = 呼ぶメソッド名）を発行し、
サーバーはそれを送り主の DID ドキュメントの鍵で検証する。他人の DID では登録できない。

### 通知の判定

| 種類 | 見ているところ |
|---|---|
| 返信 | 投稿の `reply.parent` が自分の投稿（スレッド内の他人宛ての返信は除く） |
| メンション | 投稿の facets に自分の DID |
| 引用 | 投稿の embed が自分の投稿 |
| いいね・リポスト | `subject` が自分の投稿。同じ投稿へのものは端末上で最新の 1 件に上書き |
| フォロー | `subject` が自分の DID |

自分の操作、ミュート中のユーザー、ミュートワードを含むものは送らない（ミュートは Jetstream から見えないので、アプリが登録時に送る）。

## 本番環境（2026 年 10 月に構築）

| 項目 | 内容 |
|---|---|
| ホスティング | Google Cloud Compute Engine の無料枠 |
| VM | `bluepicca-push`・e2-micro・`us-east1-b`・Debian 13・標準永続ディスク 30GB |
| ドメイン | DuckDNS の `<サブドメイン>.duckdns.org`（VM の IP を 5 分ごとに自動更新） |
| HTTPS | Caddy（Let's Encrypt の証明書を自動取得・更新） |
| サーバーの DID | `did:web:<サブドメイン>.duckdns.org` |
| 常時起動 | systemd の `bluepicca-push.service`（落ちても 5 秒後に再起動） |
| APNs | トークン認証の .p8 キー。Team ID は `TPXR4FNVUK`、トピックは `lapipearpopo.bskyapp` |
| Node.js | 26.13.0（`server/.node-version`） |

### VM 上のファイル

| 場所 | 中身 |
|---|---|
| `/opt/bluepicca-push` | アプリ本体（デプロイのたびに入れ替わる） |
| `/etc/bluepicca-push/env` | 設定（`SERVICE_DID`、`APNS_KEY_ID` など） |
| `/etc/bluepicca-push/AuthKey.p8` | APNs キー |
| `/etc/bluepicca-push/duckdns.env` | DuckDNS のサブドメインと token |
| `/var/lib/bluepicca-push/` | SQLite（登録された端末と Jetstream の cursor） |
| `/etc/caddy/Caddyfile` | HTTPS の設定（デプロイのたびに書き直す） |

## 構築した手順（振り返り）

1. **APNs キー**：Apple Developer → Keys で APNs キーを作り、.p8 と Key ID を控えた（.p8 は再ダウンロード不可なので保管する）
2. **手元の環境**：anyenv の nodenv で Node 26.13.0 を入れ、`server/` で `npm ci` と `npm test` を確認した
3. **Google Cloud の準備**：`brew install --cask google-cloud-sdk` → `gcloud init` でプロジェクト作成 →
   請求先アカウントをリンク → `gcloud services enable compute.googleapis.com` → 予算アラートを設定
4. **VM 作成**：`bash server/deploy/gce/create-vm.sh`（VM と 80/443 のファイアウォールを作り、外部 IP を表示）
5. **DuckDNS**：サブドメインを作り、VM の IP を登録して token を控えた
6. **初回デプロイ**：`bash server/deploy/gce/deploy.sh`（Node と Caddy を入れ、設定の雛形を作って止まる）
7. **設定**：.p8 を `gcloud compute scp` で送って `/etc/bluepicca-push/AuthKey.p8` に置き、
   `env` の `SERVICE_DID` と `APNS_KEY_ID` を埋め、`duckdns.env` を作った
8. **再デプロイ**：`deploy.sh` をもう一度実行し、`https://<サブドメイン>.duckdns.org/health` が `{"ok":true,...}` を返すことを確認した
9. **アプリ**：`PushServerConfig` に `baseURL` と `serviceDid` を入れて実機でビルドし、通知をオンにした
10. **動作確認**：別アカウントからのリプライで、アプリを閉じた状態でもプッシュ通知が届いた

## 日々の運用

コードを変えたら、リポジトリのルートで同じコマンドを実行すれば更新される（ビルドに失敗したら動いている版が残る）。

```bash
bash server/deploy/gce/deploy.sh
```

ログを見る。

```bash
gcloud compute ssh bluepicca-push --zone=us-east1-b --command='sudo journalctl -u bluepicca-push -n 50 --no-pager'
```

登録されている端末の数を見る。

```bash
curl https://<サブドメイン>.duckdns.org/health
```

### 困ったとき

| 症状 | 見るところ |
|---|---|
| 通知が来ない | ログに `Jetstream connected` があるか。`APNs 400 ...` があれば理由が書いてある |
| `devices` が 0 のまま | アプリの通知がオンか、`PushServerConfig` が入っているか。Xcode のログに `Push registration failed` が出ていないか |
| `APNs 400 BadDeviceToken` | 端末の環境と APNs の環境が合っていない。Xcode から入れたビルドは sandbox、TestFlight・App Store は production（アプリが自動で送り分ける） |
| `/health` に外からつながらない | DuckDNS の IP が VM の外部 IP と一致しているか。VM で `systemctl status caddy` |
| VM を止めて起動したら IP が変わった | 5 分以内に DuckDNS の自動更新で直る |

## 費用

- 無料枠の条件（e2-micro 1 台・us-west1 / us-central1 / us-east1・標準永続ディスク 30GB まで・北米からの送信は月 1GB まで）に収めている
- 外部 IPv4 アドレスは無料枠の対象外という情報があり、月数百円かかる可能性がある。「お支払い → レポート」で確認する
- 予算アラートを設定済み

## 残っている作業

- [ ] `PushServerConfig` の値をコミットする（手元で入れただけなら）
- [ ] プライバシーポリシー（`docs/privacy-policy.html`）に、端末トークン・DID・ミュート中のユーザー・ミュートワードを中継サーバーに保存することを追記する（App Store 提出前に必須）
- [ ] TestFlight のビルドで、production の APNs 経由でも届くか確認する
- [ ] 通知をタップしたときに該当の投稿やリプライ画面を開く
- [ ] ブロックした相手からの通知を弾く（アプリからブロック一覧も送る）
- [ ] `npm audit` が警告している zod の脆弱性（Bluesky 公式ライブラリ経由）は、ライブラリの更新を待つ
