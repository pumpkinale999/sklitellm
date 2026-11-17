#!/usr/bin/env bash
# On-box helper: nginx + unit + ensure host DB. Prefer publish.sh from laptop for full sync+build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
ENV_DIR="${ENV_DIR:-/etc/litellm}"

echo "install: repo=$REPO"

sudo mkdir -p "$ENV_DIR"
if [[ ! -f "$ENV_DIR/litellm.env" ]]; then
  sudo cp "$ROOT/litellm.env.example" "$ENV_DIR/litellm.env"
  sudo chown root:devops "$ENV_DIR/litellm.env"
  sudo chmod 660 "$ENV_DIR/litellm.env"
  echo "created $ENV_DIR/litellm.env — fill DATABASE_URL / keys"
fi

sudo cp "$ROOT/nginx-site-skportal.conf.example" /etc/nginx/sites-available/skportal
sudo ln -sf /etc/nginx/sites-available/skportal /etc/nginx/sites-enabled/skportal
sudo cp "$ROOT/litellm.service" /etc/systemd/system/litellm.service
sudo systemctl daemon-reload
sudo nginx -t
sudo systemctl reload nginx

chmod +x "$ROOT/ensure-host-db.sh"
if grep -q 'REPLACE_DB_PASSWORD' "$ENV_DIR/litellm.env" 2>/dev/null; then
  echo "skip ensure-host-db until DATABASE_URL password is set"
else
  sudo "$ROOT/ensure-host-db.sh"
fi

echo "install: done. Build/start: sudo systemctl enable --now litellm"
echo "  (or from laptop: ./deploy/skportal/publish.sh)"
