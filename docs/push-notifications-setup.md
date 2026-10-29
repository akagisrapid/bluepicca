# プッシュ通知の構築手順（詳細版）

Bluepicca のプッシュ通知を、何もない状態から本番で届くようにするまでの手順。
しくみの説明や運用方法は [push-notifications.md](push-notifications.md) にある。ここでは
**各手順で何をしているのか、どうなれば成功なのか、どこでつまずきやすいのか** を順に説明する。

秘密の値は `<...>` で示す。次の 3 つはリポジトリに入れない。

- APNs キー（`AuthKey_XXXXXXXXXX.p8`）
- DuckDNS の token
- Google Cloud の請求先アカウント ID

## 全体の流れ

| # | 手順 | 作業する場所 | 目安 |
|---|---|---|---|
| 1 | APNs キーを作る | Apple Developer のサイト | 5 分 |
| 2 | 手元の Node.js を 26 にしてテストする | 手元の Mac | 10 分 |
| 3 | Google Cloud を準備する | 手元の Mac・Google Cloud コンソール | 15 分 |
| 4 | VM を作る | 手元の Mac | 5 分 |
| 5 | DuckDNS でドメインを取る | DuckDNS のサイト | 5 分 |
| 6 | 初回デプロイ | 手元の Mac → VM | 5〜10 分 |
| 7 | APNs キーと設定を VM に置く | VM | 5 分 |
| 8 | 再デプロイして公開を確認する | 手元の Mac | 5 分 |
| 9 | アプリに接続先を入れる | Xcode | 5 分 |
| 10 | 実機で通知を確認する | iPhone | 5 分 |

---

## 1. APNs キーを作る

### 何のためか

iOS のプッシュ通知は、必ず Apple の APNs（Apple Push Notification service）を通して届く。
APNs は「このアプリの開発者だけが、このアプリに送れる」ように、送る側に鍵を求める。
中継サーバーはこの鍵で署名したトークンを付けて APNs に送る。

鍵には古い「証明書（.p12）」方式と新しい「トークン認証（.p8）」方式があり、ここでは .p8 を使う。
.p8 には次の利点がある。

- 有効期限がない（証明書は 1 年ごとに更新が必要）
- 開発用（sandbox）と本番用（production）の両方に 1 つの鍵で送れる
- 同じチームの他のアプリにも使える

### 手順

1. [Apple Developer → Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list) を開く
2. 「Keys」の横の「＋」を押す
3. Key Name に分かりやすい名前を入れる（例: `Bluepicca Push`）
4. 「Apple Push Notifications service (APNs)」にチェックを入れる。環境を選べる場合は「Sandbox & Production」にする
5. 「Continue」→「Register」
6. 「Download」で `AuthKey_XXXXXXXXXX.p8` をダウンロードする
7. 画面に出る **Key ID**（10 文字の英数字）を控える。ファイル名の `AuthKey_` の後ろと同じ

### 成功の目安

`AuthKey_XXXXXXXXXX.p8` が手元にあり、Key ID がわかっている。

### 注意

- **.p8 は一度しかダウンロードできない。** なくしたらキーを作り直す（古いキーは失効させる）
- .p8 はパスワードと同じ扱い。リポジトリに入れない（`server/.gitignore` で `*.p8` は除外済み）、
  チャットやメールに貼らない。パスワードマネージャーなどに保管する
- Team ID は `TPXR4FNVUK`。Apple Developer の Membership ページでも確認できる

---

## 2. 手元の Node.js を 26 にしてテストする

### 何のためか

中継サーバーは TypeScript で書かれていて、Node.js 26 で動く。本番に置く前に、手元で依存パッケージを入れて
テストが通ることを確認しておくと、後で問題が起きたときに「サーバーのコードの問題か、本番環境の問題か」を切り分けられる。

Node のバージョンは `server/.node-version`（中身は `26.13.0`）で指定している。nodenv はこのファイルを読んで、
`server/` の中では自動でこの版に切り替える。

### 手順

nodenv が anyenv 経由で入っている場合、バージョンの一覧（node-build）は Homebrew ではなく anyenv の下にある。
まずこれを更新しないと、新しい 26.13.0 が一覧に出てこない。

```bash
anyenv update
```

`anyenv: no such command 'update'` と出たら、anyenv-update プラグインがないので node-build を直接更新する。

```bash
git -C "$(nodenv root)/plugins/node-build" pull
```

26 系が一覧に出ることを確認する。

```bash
nodenv install --list | grep '^26'
```

ブランチを最新にして `server/` に移る。

```bash
git pull origin claude/nice-heisenberg-mwckva
```

```bash
cd server
```

`.node-version` を読んで 26.13.0 を入れる。

```bash
nodenv install
```

```bash
node -v
```

依存パッケージを入れてテストする。

```bash
npm ci
```

```bash
npm test
```

### 成功の目安

- `node -v` が `v26.13.0`
- `npm test` の最後が `ℹ pass 19` / `ℹ fail 0`

### 注意

- `node -v` が古いままなら、`which node` が `~/.anyenv/envs/nodenv/shims/node` を指しているか確認する。
  違う場合は Homebrew の Node が PATH の前にいるか、シェルの設定に `eval "$(anyenv init -)"` がない
- `npm ci` で「esbuild の install script が許可されていない」という警告が出ることがある。
  npm 11 の安全機能によるもので、テストに使っている tsx は問題なく動くので無視してよい
- `npm install` ではなく `npm ci` を使う。`package-lock.json` のとおりに入れるので、本番と同じ版になる

---

## 3. Google Cloud を準備する

### 何のためか

中継サーバーは Jetstream に常時つなぎっぱなしにする必要があるため、短時間だけ動く環境（Cloudflare Workers や
Lambda など）では動かない。常に動いている VM が要る。Google Cloud には、条件を守れば無料で使い続けられる
e2-micro の無料枠があるので、それを使う。

### 手順

**gcloud を入れる。** Google Cloud をコマンドで操作するためのツール。

```bash
brew install --cask google-cloud-sdk
```

**ログインとプロジェクトの作成。** ブラウザが開くので Google アカウントでログインし、「Create a new project」を選ぶ。

```bash
gcloud init
```

- プロジェクト ID は世界中で一意なので、使われていたら末尾に数字などを付ける（例: `bluepicca-push-1234`）
- 既定のゾーンを聞かれたら `us-east1-b` を選ぶ（聞かれなければ飛ばしてよい）

**請求先アカウントをリンクする。** 無料枠の範囲で使う場合でも、クレジットカードを登録した請求先アカウントが必要。

```bash
gcloud billing accounts list
```

一覧が空なら、[お支払い](https://console.cloud.google.com/billing)のページでカードを登録して請求先アカウントを作る。
表示された `ACCOUNT_ID`（`XXXXXX-XXXXXX-XXXXXX` の形）をプロジェクトにリンクする。

```bash
gcloud billing projects link <プロジェクトID> --billing-account=<ACCOUNT_ID>
```

**Compute Engine（VM のサービス）を有効にする。** 1〜2 分かかることがある。

```bash
gcloud services enable compute.googleapis.com
```

**予算アラートを作る。** [予算とアラート](https://console.cloud.google.com/billing/budgets)で、
月 100 円などの予算を作る。無料枠の条件を外れて課金が始まったときに、メールで気づける。

### 成功の目安

`gcloud services enable` がエラーなく終わる。

### 注意

- 後の手順で `gcloud` がプロジェクトを見失ったときは、`gcloud config set project <プロジェクトID>` で指定し直す
- 予算アラートは「通知」だけで、課金を止めはしない。届いたら「お支払い → レポート」で原因を確認する

---

## 4. VM を作る

### 何のためか

中継サーバーを動かすマシンを作る。無料枠に収めるため、次の条件で作る。

| 項目 | 値 | 理由 |
|---|---|---|
| マシンタイプ | e2-micro | 無料枠の対象（1 台まで） |
| ゾーン | `us-east1-b` | 無料枠は us-west1 / us-central1 / us-east1 のみ。Jetstream が米国東部にあるので近い us-east1 |
| OS | Debian 13 | 軽くて安定している |
| ディスク | 標準永続ディスク（pd-standard）30GB | 無料枠は標準ディスク 30GB まで |
| ネットワークタグ | `bluepicca-push` | ファイアウォールの対象を指定するため |

あわせて、外から 80 番（HTTP）と 443 番（HTTPS）のポートにつながるようにするファイアウォールを作る。
80 番は、Caddy が HTTPS の証明書を取るとき（Let's Encrypt の確認）に使う。

### 手順

リポジトリのルートで実行する。

```bash
bash server/deploy/gce/create-vm.sh
```

### 成功の目安

最後に `34.xx.xx.xx` のような IP アドレスが 1 行表示される。次の DuckDNS で使うので控えておく。

### 注意

- **コンソールの画面から VM を作らない。** 画面で作るとディスクの既定が「バランス永続ディスク」になり、
  無料枠の対象外で課金される。スクリプトは標準ディスクで作る
- `ZONE_RESOURCE_POOL_EXHAUSTED`（ゾーンに空きがない）と出たら、別のゾーンで作る。
  その場合、以降のすべての `gcloud compute ...` と `deploy.sh` で同じゾーンを指定する

  ```bash
  ZONE=us-east1-c bash server/deploy/gce/create-vm.sh
  ```

- 表示される IP は「エフェメラル（一時的）」なもので、VM を停止して起動し直すと変わることがある。
  手順 7 で入れる DuckDNS の自動更新で吸収する

---

## 5. DuckDNS でドメインを取る

### 何のためか

アプリからサーバーには HTTPS でつなぐ（iOS は原則として HTTPS 以外の通信を許さない）。
HTTPS の証明書は IP アドレスではなくドメイン名に対して発行されるので、ドメインが要る。

また、サーバーの「身元」を表す DID を `did:web:<ドメイン>` の形で決める。
アプリは本人確認の JWT を「このドメインのサーバー宛て」として発行してもらうので、ドメインは後から変えにくい。

DuckDNS は `xxx.duckdns.org` のサブドメインを無料でもらえるサービス。

### 手順

1. https://www.duckdns.org を開き、GitHub か Google でログインする
2. 「sub domain」に名前を入れて「add domain」を押す（例: `bluepicca-push` → `bluepicca-push.duckdns.org`）
3. 作ったサブドメインの「current ip」に手順 4 の IP を入れ、「update ip」を押す
4. ページ上部の **token** を控える（手順 7 で使う）

### 成功の目安

手元の Mac で次を実行し、手順 4 の IP が返る（反映に数分かかることがある）。

```bash
dig +short <サブドメイン>.duckdns.org
```

### 注意

- **token は DuckDNS のパスワードと同じ。** 知られると、他人があなたのサブドメインの向き先を変えられる
- サブドメインはアプリに組み込むので、変えるとアプリの更新が必要になる。最初に決めたものを使い続ける

---

## 6. 初回デプロイ

### 何のためか

手元の `server/` を VM に送り、VM 上で必要なソフトを入れる。`deploy.sh` は次のことをする。

1. 手元の `server/` を（`node_modules` や .p8 を除いて）固めて VM に送る
2. VM 上で `install.sh` を root として実行する

`install.sh` は次のことをする。何度実行してもよい（すでに済んでいるものは飛ばす）。

| 処理 | 内容 |
|---|---|
| スワップを作る | e2-micro はメモリが 1GB しかないので、`npm ci` やビルドで足りなくならないよう 1GB 足す |
| Caddy を入れる | HTTPS の証明書を自動で取り、外からの通信を Node に中継するソフト |
| Node.js を入れる | `.node-version` と同じ版を nodejs.org から入れる |
| 専用ユーザーを作る | サーバーを root ではなく権限の小さい `bluepicca` ユーザーで動かす |
| 設定を確認する | `/etc/bluepicca-push/env` がなければ雛形を置いて**止まる** |

初回は設定がまだないので、雛形を置いたところで止まる。これは想定どおりの動き。

### 手順

```bash
bash server/deploy/gce/deploy.sh
```

初めて `gcloud compute ssh` を使うときは、SSH 鍵を作るか聞かれる。パスフレーズは空のまま Enter でよい。

### 成功の目安

数分後、最後に次のように出て止まる。

```
/etc/bluepicca-push/env を作りました。値を埋め、APNs キーを /etc/bluepicca-push/AuthKey.p8 に置いてから、もう一度実行してください
```

### 注意

- 途中で `apt-get` が長く止まって見えることがあるが、e2-micro は遅いので数分待つ
- SSH でつながらないときは、VM が起動しているか（`gcloud compute instances list`）、ゾーンが合っているかを確認する

---

## 7. APNs キーと設定を VM に置く

### 何のためか

サーバーが動くのに必要な秘密の値と設定を、VM の `/etc/bluepicca-push/` に置く。
このフォルダは root と `bluepicca` ユーザーしか読めないようになっている。

| ファイル | 中身 |
|---|---|
| `AuthKey.p8` | 手順 1 の APNs キー |
| `env` | サーバーの設定（環境変数） |
| `duckdns.env` | DuckDNS のサブドメインと token（IP の自動更新に使う） |

### 手順

**APNs キーを VM に送る。** ファイル名は自分のものに置き換える。

```bash
gcloud compute scp AuthKey_XXXXXXXXXX.p8 bluepicca-push:~/AuthKey.p8 --zone=us-east1-b
```

**VM に入る。**

```bash
gcloud compute ssh bluepicca-push --zone=us-east1-b
```

ここからは VM 上で実行する。

**キーを所定の場所に移す。** ホームフォルダに置いたままにしない。

```bash
sudo mv ~/AuthKey.p8 /etc/bluepicca-push/AuthKey.p8
```

**設定を書く。**

```bash
sudo nano /etc/bluepicca-push/env
```

次の 2 行を書き換える。他の行はそのままでよい。

```
SERVICE_DID=did:web:<サブドメイン>.duckdns.org
APNS_KEY_ID=<Key ID>
```

| 項目 | 意味 |
|---|---|
| `SERVICE_DID` | このサーバーの身元。アプリが本人確認の JWT を「このサーバー宛て」として発行するときに使う。ドメインと一致させる |
| `APNS_KEY_PATH` | APNs キーの場所（雛形のまま） |
| `APNS_KEY_ID` | 手順 1 の Key ID（例: `AB12CD34EF`）。`.p8` のファイル名の `AuthKey_` の後ろ |
| `APNS_TEAM_ID` | Team ID（雛形の `TPXR4FNVUK` のまま） |
| `HOST` | `127.0.0.1`（雛形のまま）。外から Node に直接つながらないようにし、必ず Caddy（HTTPS）を通す |
| `PORT` | `8080`（雛形のまま） |

nano は Ctrl+O → Enter で保存、Ctrl+X で閉じる。

**DuckDNS の自動更新を設定する。** `<サブドメイン>` は `.duckdns.org` を付けずに書く。

```bash
printf 'DUCKDNS_SUBDOMAIN=<サブドメイン>\nDUCKDNS_TOKEN=<token>\n' | sudo tee /etc/bluepicca-push/duckdns.env
```

このファイルがあると、次のデプロイで 5 分ごとに DuckDNS へ VM の今の IP を知らせるタイマーが有効になる。

**VM から抜ける。**

```bash
exit
```

### 注意

- `SERVICE_DID` を `did:web:example.duckdns.org` のままにすると、次のデプロイで止まって知らせてくれる
- `tee` で書いた内容は画面にも表示される。画面共有中などは token が映らないよう注意する

---

## 8. 再デプロイして公開を確認する

### 何のためか

設定がそろったので、もう一度 `install.sh` を最後まで走らせる。今回は次のことまで進む。

| 処理 | 内容 |
|---|---|
| ビルドして入れ替える | 新しい版を `/opt/bluepicca-push.new` でビルドし、成功したら入れ替える。失敗したら動いている版が残る |
| systemd に登録する | `bluepicca-push.service` として登録し、起動する。落ちても 5 秒後に再起動、VM の再起動後も自動で起動 |
| DuckDNS のタイマー | `duckdns.env` があれば有効にする |
| Caddy を設定する | `<サブドメイン>.duckdns.org` への HTTPS を `127.0.0.1:8080` に中継する設定を書く。証明書は自動で取る |
| 動作確認 | VM の中から `/health` を叩いて結果を表示する |

### 手順

手元の Mac のリポジトリのルートで実行する。

```bash
bash server/deploy/gce/deploy.sh
```

最後に `{"ok":true,"devices":0}` が出たら、外からも確認する。

```bash
curl https://<サブドメイン>.duckdns.org/health
```

Jetstream につながっているかをログで確認する。

```bash
gcloud compute ssh bluepicca-push --zone=us-east1-b --command='sudo journalctl -u bluepicca-push -n 20 --no-pager'
```

### 成功の目安

- `curl` で `{"ok":true,"devices":0}` が返る（`devices` は登録された端末の数で、まだ 0）
- ログに `Jetstream connected (cursor: live)` がある

### 注意

- `curl` が証明書のエラーになるときは、Caddy が証明書を取り終えていない。1〜2 分待つ。
  それでも続くなら、DuckDNS の IP が VM の IP と合っているか（手順 5 の `dig`）と、80 番のファイアウォールを確認する
- ログに `Jetstream error` が繰り返し出るなら、VM から外へつながっていない可能性がある

---

## 9. アプリに接続先を入れる

### 何のためか

アプリにサーバーの場所を教える。`PushServerConfig` が空のあいだ、アプリはプッシュを使わず、
端末内の定期確認（遅れがちな予備の方式）だけで通知する。値を入れるとプッシュに切り替わる。

### 手順

`bskyapp/Service/PushRegistrationService.swift` の `PushServerConfig` を書き換える。

```swift
static let baseURL = "https://<サブドメイン>.duckdns.org"
static let serviceDid = "did:web:<サブドメイン>.duckdns.org"
```

`serviceDid` は、手順 7 の `SERVICE_DID` と**完全に同じ**にする。違うと本人確認の JWT の宛先が合わず、
サーバーが登録を断る（401）。

Xcode でプロジェクトを開き、ターゲットの **Signing & Capabilities** に「Push Notifications」が
エラーなく表示されていることを確認する。`bskyapp.entitlements` に `aps-environment` を入れてあるので、
自動署名なら Xcode がプロビジョニングプロファイルに Push Notifications を付けてくれる。

### 注意

- サブドメインはアプリのバイナリに含まれる公開情報なので、コミットしてよい。token と .p8 はコミットしない
- 値を入れたら、忘れずにコミットする

---

## 10. 実機で通知を確認する

### 何のためか

シミュレータでは APNs のプッシュを受け取れないので、iPhone の実機で最後まで確かめる。

アプリの中では次の順に進む。

1. 通知をオンにすると、iOS に APNs の端末トークンを発行してもらう
2. 自分の PDS に本人確認の JWT を発行してもらう
3. 端末トークン・通知する種類・ミュート設定と JWT をサーバーに送る
4. サーバーは JWT を検証して登録する。以降、Jetstream で自分宛ての出来事を見つけると APNs に送る

### 手順

1. iPhone をつなぎ、Xcode から実機にビルドして実行する
2. アプリの 設定 → 通知 → 「通知を受け取る」をオンにし、通知を許可する
3. 登録されたか確認する。`devices` が 1 になれば成功

   ```bash
   curl https://<サブドメイン>.duckdns.org/health
   ```

4. アプリを閉じる（ホームに戻るか、アプリスイッチャーで上にスワイプする）
5. 別のアカウントから、自分の投稿にリプライしてもらう
6. 数秒以内に「〇〇さんが返信しました」の通知が届けば完成

### 注意

- **Xcode から入れたビルドは開発用（sandbox）の APNs に登録される。** TestFlight と App Store の
  ビルドは本番用（production）の APNs を使う。アプリが自動で送り分けるが、TestFlight でも一度確かめる
- `devices` が 0 のままなら、Xcode のコンソールに `Push registration failed` が出ていないか見る。
  401 なら手順 9 の `serviceDid` とサーバーの `SERVICE_DID` が一致しているかを確認する
- 登録できているのに届かないときは、手順 8 のログを見る。`APNs 400 BadDeviceToken` は sandbox と
  production の取り違え、`APNs 403` は Key ID や Team ID の間違いが多い
- 自分で自分の投稿にリプライしても通知は来ない（自分の操作は通知しない仕様）

---

## この後にやること

- `PushServerConfig` の値をコミットする
- プライバシーポリシー（`docs/privacy-policy.html`）に、端末トークン・DID・ミュート中のユーザー・
  ミュートワードを中継サーバーに保存することを追記する（App Store 提出前に必須）
- TestFlight のビルドで、production の APNs 経由でも届くか確認する

運用（更新・ログ・困ったとき）は [push-notifications.md](push-notifications.md) を参照。
