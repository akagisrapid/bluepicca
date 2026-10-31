# Google Cloud（無料枠の e2-micro）で動かす

Google Cloud の無料枠に収まる構成で、プッシュ中継サーバーを常時動かす手順。

```
[Bluepicca] ──HTTPS──▶ Caddy（証明書は自動）──▶ Node（127.0.0.1:8080）──▶ APNs
                                                   ▲
                                         Jetstream（米国東部）
```

- VM: e2-micro・us-east1・Debian 13・標準永続ディスク 30GB
- ドメイン: DuckDNS の無料サブドメイン（`xxx.duckdns.org`）。VM の IP が変わっても 5 分ごとに自動で更新する
- 常時起動: systemd。落ちても 5 秒後に再起動し、VM の再起動後も自動で立ち上がる

## 無料枠の条件（外れると課金される）

- e2-micro が **1 台**まで、リージョンは **us-west1 / us-central1 / us-east1** のみ
- ディスクは **標準永続ディスク（pd-standard）30GB** まで。コンソールで作ると既定が「バランス」になり有料なので注意
  （`create-vm.sh` は pd-standard で作る）
- 北米からの送信は月 1GB まで。このサーバーの送信は APNs への小さな通知だけなので収まる見込み
- 外部 IPv4 アドレスは無料枠の対象外という情報があり、月数百円かかる可能性がある。
  作成後に「お支払い → レポート」で確認する

念のため「お支払い → 予算とアラート」で、月 100 円などの予算アラートを作っておく。

## 0. 準備（手元の Mac）

```bash
brew install --cask google-cloud-sdk
```

```bash
gcloud init
```

- `gcloud init` でログインし、プロジェクトを作る（または選ぶ）
- コンソールでそのプロジェクトに請求先アカウントをリンクする（無料枠でも必要）
- Compute Engine API を有効にする

```bash
gcloud services enable compute.googleapis.com
```

APNs キー（.p8）と Key ID も用意しておく（`server/README.md` の「1. APNs キーを作る」）。

## 1. VM を作る

リポジトリのルートで実行する。最後に VM の外部 IP が表示される。

```bash
bash server/deploy/gce/create-vm.sh
```

## 2. DuckDNS でドメインを取る

1. https://www.duckdns.org に GitHub か Google でログインする
2. サブドメインを作り（例: `bluepicca-push` → `bluepicca-push.duckdns.org`）、current ip に 1 の IP を入れる
3. ページ上部の **token** を控える

## 3. 初回デプロイ（設定ファイルの雛形ができて止まる）

```bash
bash server/deploy/gce/deploy.sh
```

Node.js と Caddy が入り、`/etc/bluepicca-push/env を作りました` と出て止まれば正常。

## 4. APNs キーと設定を VM に置く

キーを VM に送る（ファイル名は自分のものに置き換える）。

```bash
gcloud compute scp AuthKey_XXXXXXXXXX.p8 bluepicca-push:~/AuthKey.p8 --zone=us-east1-b
```

VM に入る。

```bash
gcloud compute ssh bluepicca-push --zone=us-east1-b
```

ここからは VM 上で実行する。キーを所定の場所に移す。

```bash
sudo mv ~/AuthKey.p8 /etc/bluepicca-push/AuthKey.p8
```

設定を書く。`SERVICE_DID` を `did:web:<サブドメイン>.duckdns.org` に、`APNS_KEY_ID` を Key ID にする。

```bash
sudo nano /etc/bluepicca-push/env
```

DuckDNS の自動更新用の設定を作る（`<サブドメイン>` と `<token>` を置き換える。サブドメインは `.duckdns.org` を付けない）。

```bash
printf 'DUCKDNS_SUBDOMAIN=<サブドメイン>\nDUCKDNS_TOKEN=<token>\n' | sudo tee /etc/bluepicca-push/duckdns.env
```

```bash
exit
```

## 5. もう一度デプロイする

```bash
bash server/deploy/gce/deploy.sh
```

最後に `{"ok":true,"devices":0}` が出れば起動している。外からも確認する（証明書の取得に 1 分ほどかかることがある）。

```bash
curl https://<サブドメイン>.duckdns.org/health
```

## 6. アプリに接続先を入れる

`bskyapp/Service/PushRegistrationService.swift` の `PushServerConfig`:

```swift
static let baseURL = "https://<サブドメイン>.duckdns.org"
static let serviceDid = "did:web:<サブドメイン>.duckdns.org"
```

## 運用

コードを変えたら、同じコマンドで更新できる（ビルドに失敗したときは動いている版がそのまま残る）。

```bash
bash server/deploy/gce/deploy.sh
```

ログを見る（VM 上で実行）。

```bash
sudo journalctl -u bluepicca-push -f
```

メモリや CPU の様子を見る（VM 上で実行）。

```bash
systemctl status bluepicca-push
```

| 場所 | 中身 |
|---|---|
| `/opt/bluepicca-push` | アプリ本体（デプロイのたびに入れ替わる） |
| `/etc/bluepicca-push/` | `env`（設定）、`AuthKey.p8`、`duckdns.env` |
| `/var/lib/bluepicca-push/` | SQLite（登録された端末と Jetstream の cursor） |
| `/etc/caddy/Caddyfile` | HTTPS の設定（deploy のたびに書き直す） |

VM 名やゾーンを変えたときは、`INSTANCE=... ZONE=... bash server/deploy/gce/deploy.sh` のように指定する。
