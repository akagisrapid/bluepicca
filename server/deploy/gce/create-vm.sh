#!/usr/bin/env bash
# Google Cloud の無料枠（e2-micro・us-east1・標準永続ディスク 30GB）で VM と、80/443 を開けるファイアウォールを作る。
# 手元の Mac で一度だけ実行する。gcloud でログインとプロジェクトの選択を済ませておくこと
set -euo pipefail

INSTANCE="${INSTANCE:-bluepicca-push}"
# 無料枠は us-west1 / us-central1 / us-east1 のみ。Jetstream（米国東部）に近い us-east1 にする
ZONE="${ZONE:-us-east1-b}"

gcloud compute instances create "$INSTANCE" \
  --zone="$ZONE" \
  --machine-type=e2-micro \
  --image-family=debian-13 \
  --image-project=debian-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-standard \
  --tags=bluepicca-push

# 80 は Caddy が HTTPS の証明書を取るときに使う
if ! gcloud compute firewall-rules describe bluepicca-push-web >/dev/null 2>&1; then
  gcloud compute firewall-rules create bluepicca-push-web \
    --allow=tcp:80,tcp:443 \
    --target-tags=bluepicca-push
fi

gcloud compute instances describe "$INSTANCE" --zone="$ZONE" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)'
