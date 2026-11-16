#!/usr/bin/env bash
# Mac local: stop LiteLLM Postgres compose stack
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
docker compose -f deploy/mac/docker-compose.yml down
echo "[dev-down] stopped deploy/mac stack"
