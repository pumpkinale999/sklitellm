#!/usr/bin/env bash
# From laptop: rsync repo → skportal:/opt/litellm, install runtime, restart.
#
# Default: PyPI wheel litellm==<pyproject version> (no local Rust build).
# Source tree stays on disk for config + future editable/rust workflow.
# Reuses host Postgres 127.0.0.1:5432 (role/db litellm).
#
# Usage: ./deploy/skportal/publish.sh
# Optional: LITELLM_INSTALL_MODE=editable  (needs rustc/cargo on skportal)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOST="${SKPORTAL_HOST:-skportal}"
REMOTE_DIR="${REMOTE_DIR:-/opt/litellm}"
MODE="${LITELLM_INSTALL_MODE:-pypi}"
VER="$(python3 -c "import re,pathlib; t=pathlib.Path('$ROOT/pyproject.toml').read_text(); print(re.search(r'(?m)^version\s*=\s*\"([^\"]+)\"', t).group(1))")"

echo "publish: $ROOT → ${HOST}:${REMOTE_DIR} (mode=$MODE ver=$VER)"

ssh "$HOST" "sudo mkdir -p '${REMOTE_DIR}' && sudo chown -R devops:devops '${REMOTE_DIR}'"

rsync -az --delete \
  -e 'ssh -o BatchMode=yes' \
  --exclude '.venv/' \
  --exclude 'venv/' \
  --exclude '.git/' \
  --exclude '__pycache__/' \
  --exclude '.mypy_cache/' \
  --exclude '.pytest_cache/' \
  --exclude '.ruff_cache/' \
  --exclude 'node_modules/' \
  --exclude 'ui/litellm-dashboard/node_modules/' \
  --exclude 'ui/litellm-dashboard/.next/' \
  --exclude '*.pyc' \
  --exclude '.env' \
  --exclude 'config.local.yaml' \
  --exclude 'deploy/mac/' \
  "$ROOT/" "${HOST}:${REMOTE_DIR}/"

ssh "$HOST" "bash -s" <<REMOTE
set -euo pipefail
REMOTE_DIR='${REMOTE_DIR}'
MODE='${MODE}'
VER='${VER}'
export PATH="\$HOME/.local/bin:\$PATH"

sudo mkdir -p /etc/litellm
if [[ ! -f /etc/litellm/litellm.env ]]; then
  sudo cp "\${REMOTE_DIR}/deploy/skportal/litellm.env.example" /etc/litellm/litellm.env
  sudo chown root:devops /etc/litellm/litellm.env
  sudo chmod 660 /etc/litellm/litellm.env
  echo "created /etc/litellm/litellm.env — fill secrets then re-run"
  exit 1
fi

# Quote GENERIC_SCOPE; ensure SERVER_ROOT_PATH=/litellm (UI subpath)
sudo python3 - <<'PY'
from pathlib import Path
p = Path("/etc/litellm/litellm.env")
lines = p.read_text().splitlines()
out = []
seen_root = False
for line in lines:
    if line.startswith("GENERIC_SCOPE=") and not line.startswith('GENERIC_SCOPE="'):
        line = 'GENERIC_SCOPE="%s"' % line.split("=", 1)[1]
    if line.startswith("SERVER_ROOT_PATH="):
        line = "SERVER_ROOT_PATH=/litellm"
        seen_root = True
    out.append(line)
if not seen_root:
    out.append("SERVER_ROOT_PATH=/litellm")
p.write_text("\\n".join(out) + "\\n")
PY

sudo cp "\${REMOTE_DIR}/deploy/skportal/nginx-site-skportal.conf.example" /etc/nginx/sites-available/skportal
sudo ln -sf /etc/nginx/sites-available/skportal /etc/nginx/sites-enabled/skportal
sudo cp "\${REMOTE_DIR}/deploy/skportal/litellm.service" /etc/systemd/system/litellm.service
sudo systemctl daemon-reload
sudo nginx -t && sudo systemctl reload nginx

chmod +x "\${REMOTE_DIR}/deploy/skportal/ensure-host-db.sh"
sudo "\${REMOTE_DIR}/deploy/skportal/ensure-host-db.sh"
sudo docker rm -f litellm_proxy litellm_db 2>/dev/null || true

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

cd "\${REMOTE_DIR}"
[[ -d .venv ]] || uv venv --python python3.12 .venv
source .venv/bin/activate

if [[ "\$MODE" == "editable" ]]; then
  echo "editable install (requires rustc)…"
  uv pip install -e '.[proxy,extra_proxy]'
else
  echo "PyPI install litellm[proxy,extra_proxy]==\$VER"
  uv pip install "litellm[proxy,extra_proxy]==\$VER"
fi

uv pip install prisma
set -a
source <(grep -E '^(DATABASE_URL)=' /etc/litellm/litellm.env)
set +a
prisma generate --schema schema.prisma
prisma py fetch

python -c "from importlib.metadata import version; print('litellm', version('litellm'))"
sudo systemctl enable litellm
sudo systemctl restart litellm
for i in \$(seq 1 36); do
  code=\$(curl -sS -m 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:4000/health/liveliness 2>/dev/null || echo 000)
  echo "wait \$i liveliness=\$code"
  [[ "\$code" == "200" ]] && break
  sleep 5
done
curl -fsS -H 'Host: skportal.shukun.net' http://127.0.0.1/litellm/health/liveliness
echo
# UI under SERVER_ROOT_PATH: pages 200; bare usage redirects under /litellm
code_ui=\$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: skportal.shukun.net' 'http://127.0.0.1/litellm/ui/')
code_usage=\$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: skportal.shukun.net' 'http://127.0.0.1/litellm/ui/usage/')
echo "ui/=\$code_ui usage/=\$code_usage"
[[ "\$code_ui" == "200" && "\$code_usage" == "200" ]] || { echo "FAIL: expected 200 for /litellm/ui/ and /usage/"; exit 1; }
loc=\$(curl -sSI -H 'Host: skportal.shukun.net' 'http://127.0.0.1/litellm/ui/usage' | tr -d '\\r' | grep -i '^location:' | head -1 | sed 's/^[Ll]ocation:[[:space:]]*//')
echo "ui/usage Location: \$loc"
case "\$loc" in
  */litellm/ui/usage*) ;;
  *) echo "FAIL: expected Location under /litellm/ui/usage, got: \$loc" >&2; exit 1 ;;
esac
code_legacy=\$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: skportal.shukun.net' 'http://127.0.0.1/ui/usage/')
echo "legacy /ui/usage/ -> \$code_legacy (expect 301)"
[[ "\$code_legacy" == "301" ]] || { echo "FAIL: legacy /ui should 301"; exit 1; }
REMOTE

echo "publish: done"
