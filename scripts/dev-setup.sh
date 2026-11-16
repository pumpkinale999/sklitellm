#!/usr/bin/env bash
# Mac local: create .venv and editable-install litellm[proxy,extra_proxy]
# (extra_proxy pulls prisma for DB-backed UI / virtual keys)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PYTHON="${PYTHON:-python3.11}"
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON=python3

if [[ ! -d .venv ]]; then
  echo "[dev-setup] creating .venv with $PYTHON"
  "$PYTHON" -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

# Avoid dead macOS system HTTP proxies during large downloads / rustup.
export NO_PROXY="${NO_PROXY:-*}"
export no_proxy="${no_proxy:-*}"
export HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= ALL_PROXY= all_proxy=

if command -v uv >/dev/null 2>&1; then
  echo "[dev-setup] uv pip install -e '.[proxy,extra_proxy]'"
  uv pip install -e '.[proxy,extra_proxy]'
else
  echo "[dev-setup] pip install -e '.[proxy,extra_proxy]'"
  pip install -U pip
  pip install -e '.[proxy,extra_proxy]'
fi

if [[ ! -f .env ]]; then
  cp deploy/mac/.env.example .env
  if command -v openssl >/dev/null 2>&1; then
    MASTER="sk-$(openssl rand -hex 32)"
    SALT="sk-$(openssl rand -hex 32)"
    # portable in-place replace for macOS sed
    sed -i.bak "s|LITELLM_MASTER_KEY=sk-change-me-to-a-long-random-string|LITELLM_MASTER_KEY=${MASTER}|" .env
    sed -i.bak "s|LITELLM_SALT_KEY=sk-change-me-salt-also-long-random|LITELLM_SALT_KEY=${SALT}|" .env
    rm -f .env.bak
    echo "[dev-setup] wrote .env with random master/salt keys"
  else
    echo "[dev-setup] wrote .env from example — set LITELLM_MASTER_KEY / LITELLM_SALT_KEY"
  fi
fi

if [[ ! -f config.local.yaml ]]; then
  cp deploy/mac/config.yaml.example config.local.yaml
  echo "[dev-setup] wrote config.local.yaml"
fi

# Prisma client is required for DB-backed Proxy (UI / virtual keys).
if [[ -f schema.prisma ]]; then
  echo "[dev-setup] prisma generate"
  DATABASE_URL="${DATABASE_URL:-postgresql://llmproxy:dbpassword9090@127.0.0.1:5433/litellm}" \
    prisma generate --schema schema.prisma
fi

python -c "from importlib.metadata import version; print('[dev-setup] litellm', version('litellm'))"
echo "[dev-setup] done. Next: ./scripts/dev-db.sh && ./scripts/dev-proxy.sh"
