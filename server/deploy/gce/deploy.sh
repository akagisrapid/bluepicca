#!/usr/bin/env bash
# 手元の server/ を VM に送り、VM 上で install.sh を実行する。コードを変えたときも同じコマンドで更新できる
set -euo pipefail

INSTANCE="${INSTANCE:-bluepicca-push}"
ZONE="${ZONE:-us-east1-b}"
SERVER_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# COPYFILE_DISABLE: macOS の tar が ._ ファイルを混ぜないようにする
COPYFILE_DISABLE=1 tar -C "$SERVER_DIR" -czf - \
  --exclude=node_modules --exclude=dist --exclude='*.sqlite*' --exclude='*.p8' --exclude=.env . |
  gcloud compute ssh "$INSTANCE" --zone="$ZONE" --command='
    set -e
    rm -rf ~/bluepicca-push-src && mkdir -p ~/bluepicca-push-src
    tar -xzf - -C ~/bluepicca-push-src
    sudo bash ~/bluepicca-push-src/deploy/gce/install.sh ~/bluepicca-push-src'
