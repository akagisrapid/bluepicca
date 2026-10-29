#!/usr/bin/env bash
# VM 上で root として実行する（deploy.sh から呼ばれる）。何度実行してもよい
#   - スワップ・Caddy・Node.js（.node-version の版）を入れる
#   - アプリを /opt/bluepicca-push に置いてビルドし、systemd で常時起動する
#   - Caddy で SERVICE_DID のドメインを HTTPS で公開する
set -euo pipefail

SRC="$(cd "${1:?usage: install.sh <source dir>}" && pwd)"
APP=/opt/bluepicca-push
CONF=/etc/bluepicca-push
HERE="$SRC/deploy/gce"
NODE_VERSION="$(tr -d '[:space:]' <"$SRC/.node-version")"

# e2-micro はメモリ 1GB なので、npm ci やビルドで足りなくならないようスワップを足す
if ! swapon --show | grep -q .; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

if ! command -v caddy >/dev/null || ! command -v xz >/dev/null; then
  apt-get update
  apt-get install -y caddy curl xz-utils
fi

if [ "$(/usr/local/bin/node --version 2>/dev/null || true)" != "v$NODE_VERSION" ]; then
  arch="$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')"
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$arch.tar.xz" | tar -xJ -C /opt
  ln -sfn "/opt/node-v$NODE_VERSION-linux-$arch" /opt/node
  ln -sf /opt/node/bin/node /opt/node/bin/npm /opt/node/bin/npx /usr/local/bin/
fi

id bluepicca >/dev/null 2>&1 || useradd --system --home-dir "$APP" --shell /usr/sbin/nologin bluepicca

# 設定は初回だけ雛形を置いて止める。値を埋めて .p8 を置いてから、もう一度 deploy.sh を実行する
install -d -m 750 -o root -g bluepicca "$CONF"
if [ ! -f "$CONF/env" ]; then
  install -m 640 -o root -g bluepicca "$HERE/env.example" "$CONF/env"
  echo "$CONF/env を作りました。値を埋め、APNs キーを $CONF/AuthKey.p8 に置いてから、もう一度実行してください" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. "$CONF/env"
set +a
if [ ! -r "${APNS_KEY_PATH:-}" ] && [ -z "${APNS_KEY:-}" ]; then
  echo "APNs キー（APNS_KEY_PATH=${APNS_KEY_PATH:-未設定}）がありません" >&2
  exit 1
fi
chgrp bluepicca "$CONF"/* && chmod 640 "$CONF"/*
DOMAIN="${SERVICE_DID#did:web:}"
if [ "$DOMAIN" = "$SERVICE_DID" ] || [ "$DOMAIN" = "example.duckdns.org" ]; then
  echo "SERVICE_DID を did:web:<あなたのドメイン> にしてください" >&2
  exit 1
fi

# ビルドしてから入れ替える（失敗しても動いている版は残る）
rm -rf "$APP.new"
cp -a "$SRC" "$APP.new"
(
  cd "$APP.new"
  npm ci --no-audit --no-fund
  npm run build
  npm prune --omit=dev --no-audit --no-fund
)
rm -rf "$APP.old"
if [ -d "$APP" ]; then mv "$APP" "$APP.old"; fi
mv "$APP.new" "$APP"

install -m 644 "$HERE/bluepicca-push.service" /etc/systemd/system/
if [ -f "$CONF/duckdns.env" ]; then
  install -m 644 "$HERE/duckdns.service" "$HERE/duckdns.timer" /etc/systemd/system/
fi
systemctl daemon-reload
systemctl enable bluepicca-push
systemctl restart bluepicca-push
if [ -f "$CONF/duckdns.env" ]; then
  systemctl enable --now duckdns.timer
  systemctl start duckdns.service
fi

cat >/etc/caddy/Caddyfile <<CADDY
$DOMAIN {
  reverse_proxy 127.0.0.1:${PORT:-8080}
}
CADDY
systemctl reload caddy || systemctl restart caddy

sleep 3
curl -fsS "http://127.0.0.1:${PORT:-8080}/health" && echo
echo "https://$DOMAIN/health で外から確認できます"
