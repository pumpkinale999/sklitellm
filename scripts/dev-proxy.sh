#!/usr/bin/env bash
# Mac local: run LiteLLM Proxy from this checkout on :4000 (like skdev dev-backend.sh)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  bash "$ROOT/scripts/dev-setup.sh"
fi
# shellcheck disable=SC1091
source .venv/bin/activate

if [[ ! -f .env ]]; then
  echo "[dev-proxy] missing .env — run ./scripts/dev-setup.sh first" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

# Bypass dead macOS system HTTP proxy for outbound provider calls
export NO_PROXY="${NO_PROXY:-*}"
export no_proxy="${no_proxy:-*}"

# Default local DB (compose maps 5433)
export DATABASE_URL="${DATABASE_URL:-postgresql://llmproxy:dbpassword9090@127.0.0.1:5433/litellm}"
export STORE_MODEL_IN_DB="${STORE_MODEL_IN_DB:-True}"
PORT="${LITELLM_PORT:-4000}"

CONFIG="${LITELLM_CONFIG:-$ROOT/config.local.yaml}"
if [[ ! -f "$CONFIG" ]]; then
  cp "$ROOT/deploy/mac/config.yaml.example" "$CONFIG"
  echo "[dev-proxy] created $CONFIG"
fi

# Ensure DB is up when pointing at local compose
if [[ "$DATABASE_URL" == *"127.0.0.1:5433"* || "$DATABASE_URL" == *"localhost:5433"* ]]; then
  bash "$ROOT/scripts/dev-db.sh"
fi

if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "[dev-proxy] LITELLM_MASTER_KEY is empty in .env" >&2
  exit 1
fi

echo "[dev-proxy] UI http://127.0.0.1:${PORT}/ui  (admin / LITELLM_MASTER_KEY)"
exec litellm --config "$CONFIG" --port "$PORT" --host 127.0.0.1
