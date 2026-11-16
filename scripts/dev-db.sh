#!/usr/bin/env bash
# Mac local: start LiteLLM Postgres on host :5433 (does not use skdev :5432)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "[dev-db] docker not found" >&2
  exit 1
fi

docker compose -f deploy/mac/docker-compose.yml up -d
echo "[dev-db] waiting for healthy..."
for _ in $(seq 1 40); do
  if docker compose -f deploy/mac/docker-compose.yml exec -T db pg_isready -d litellm -U llmproxy >/dev/null 2>&1; then
    echo "[dev-db] ready on 127.0.0.1:5433"
    exit 0
  fi
  sleep 0.5
done
echo "[dev-db] postgres did not become ready" >&2
exit 1
