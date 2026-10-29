# Bluepicca プッシュ中継サーバー

Bluesky のプッシュ通知は公式アプリの APNs にしか届かないため、Bluepicca 宛てのプッシュを自前で送るサーバー。

```
[Bluesky Jetstream] ──(投稿・いいね・リポスト・フォロー)──▶ [このサーバー] ──(APNs)──▶ [Bluepicca]
                                                             ▲
[Bluepicca] ──(端末トークン・通知する種類・ミュート設定 + service auth JWT)──┘
```

- Jetstream（公開データ）を見て、登録ユーザー宛ての返信・メンション・引用・いいね・リポスト・フォローを拾う
- ユーザーのアプリパスワードやアクセストークンは受け取らない。登録時の本人確認は、アプリが PDS の
  `com.atproto.server.getServiceAuth` で発行した短命の JWT を、送り主の DID ドキュメントの鍵で検証して行う
- 見出しは `title-loc-key` で送り、アプリの `Localizable.xcstrings` の訳を iOS が当てる
- 同じ投稿へのいいね・リポストは `apns-collapse-id` で端末上の 1 件に上書きする

## 必要なもの

- Node.js 26（LTS）。`server/.node-version`（nodenv が読む）で 26.13.0 を指定している
- 常時動かせる場所（VPS、Fly.io、Railway など）。Jetstream に WebSocket をつなぎっぱなしにするので、
  Cloudflare Workers や Lambda のような短時間実行の環境では動かない
- HTTPS で公開できるドメイン（例: `push.example.com`）
- Apple Developer Program の APNs 認証キー（.p8）

## 1. APNs キーを作る

1. [Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list) で
   「Apple Push Notifications service (APNs)」にチェックを入れてキーを作る
2. .p8 をダウンロードする（再ダウンロードできないので保管する）。Key ID を控える
3. Team ID（Membership ページ。アプリは `TPXR4FNVUK`）を控える

## 2. 環境変数

| 名前 | 必須 | 説明 |
|---|---|---|
| `SERVICE_DID` | ○ | このサーバーの DID。ドメインから `did:web:push.example.com` とする。アプリの `PushServerConfig.serviceDid` と同じ値 |
| `APNS_KEY_PATH` / `APNS_KEY` | どちらか | .p8 のパス、または中身そのもの |
| `APNS_KEY_ID` | ○ | APNs キーの Key ID |
| `APNS_TEAM_ID` | ○ | Team ID |
| `APNS_TOPIC` | | バンドル ID。既定は `lapipearpopo.bskyapp` |
| `PORT` | | 既定は 8080 |
| `HOST` | | 待ち受けるアドレス。前段に Caddy などを置くときは `127.0.0.1`。既定はすべてのアドレス |
| `DB_PATH` | | SQLite のパス。既定は `bluepicca-push.sqlite`（Docker では `/data/bluepicca-push.sqlite`） |
| `JETSTREAM_URL` | | 既定は `wss://jetstream2.us-east.bsky.network/subscribe` |

## 3. 動かす

Google Cloud の無料枠（e2-micro）で動かす手順とスクリプトは [deploy/gce/README.md](deploy/gce/README.md) にある。以下は汎用の手順。

```bash
npm ci
npm run build
SERVICE_DID=did:web:push.example.com APNS_KEY_PATH=./AuthKey_XXXX.p8 APNS_KEY_ID=XXXX APNS_TEAM_ID=TPXR4FNVUK npm start
```

Docker の場合（`/data` を永続ボリュームにする）:

```bash
docker build -t bluepicca-push .
docker run -d --restart=always -p 8080:8080 -v bluepicca-push:/data \
  -e SERVICE_DID=did:web:push.example.com -e APNS_KEY="$(cat AuthKey_XXXX.p8)" \
  -e APNS_KEY_ID=XXXX -e APNS_TEAM_ID=TPXR4FNVUK bluepicca-push
```

前段に Caddy や nginx などを置いて HTTPS で公開する。`GET /health` で登録端末数が返る。

## 4. アプリ側の設定

`bskyapp/Service/PushRegistrationService.swift` の `PushServerConfig` に入れる。空のあいだは
プッシュを使わず、端末内の定期確認だけで通知する。

```swift
static let baseURL = "https://push.example.com"
static let serviceDid = "did:web:push.example.com"
```

Xcode から実機で動かしたビルドは sandbox、TestFlight と App Store のビルドは production の APNs に
登録される（アプリが自動で切り替えて送る）。

## API

どちらも `Authorization: Bearer <service auth JWT>`（`aud` = `SERVICE_DID`、`lxm` = メソッド名）が必要。

- `POST /xrpc/lapipearpopo.bskyapp.push.register`
  `{ token, environment: "sandbox" | "production", reasons: [...], mutedDids: [...], muteWords: [...] }`
- `POST /xrpc/lapipearpopo.bskyapp.push.unregister` `{ token }`

## 運用メモ

- Jetstream の cursor を 10 秒ごとに保存し、再起動後は続きから読む。ただし 10 分以上止まっていたときは
  古い通知をまとめて送らないよう、最新から読み直す
- APNs が無効と返した端末トークン（アプリ削除など）は自動で消す
- アカウントのミュートは非公開で Jetstream から見えないため、アプリが登録時にミュート中のユーザーと
  ミュートワードを送り、サーバー側で弾く。アプリを開いたときに変更があれば送り直す
- ブロックは見ていない。ブロックした相手のメンションなども届きうるので、気になるならアプリからブロック一覧も送るようにする

## 開発

```bash
npm test          # node:test
npm run typecheck
npm run dev       # tsx watch
```
