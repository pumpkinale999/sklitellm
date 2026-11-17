#!/usr/bin/env bash
# Create role+DB `litellm` on skportal host Postgres if missing.
# Reads DATABASE_URL from /etc/litellm/litellm.env
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/litellm/litellm.env}"
[[ -f "$ENV_FILE" ]] || { echo "missing $ENV_FILE" >&2; exit 1; }

DATABASE_URL="$(sudo grep -E '^DATABASE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
export DATABASE_URL
[[ -n "$DATABASE_URL" ]] || { echo "DATABASE_URL empty" >&2; exit 1; }

sudo -u postgres DATABASE_URL="$DATABASE_URL" python3 - <<'PY'
import os
import subprocess
import urllib.parse

u = urllib.parse.urlparse(os.environ["DATABASE_URL"])
user = u.username or "litellm"
password = urllib.parse.unquote(u.password or "")
db = (u.path or "/litellm").lstrip("/") or "litellm"
if not password or password == "REPLACE_DB_PASSWORD":
    raise SystemExit("set a real password in DATABASE_URL first")

def psql(*args: str) -> str:
    return subprocess.check_output(["psql", "-v", "ON_ERROR_STOP=1", *args], text=True).strip()

# Role
exists = psql("-tAc", f"SELECT 1 FROM pg_roles WHERE rolname = '{user}'")
# password via dollar-quote to avoid injection/escape issues
tag = "pw" + os.urandom(4).hex()
pwd_lit = f"${tag}${password}${tag}$"
if exists != "1":
    psql("-c", f"CREATE ROLE {user} LOGIN PASSWORD {pwd_lit}")
    print(f"created role {user}")
else:
    psql("-c", f"ALTER ROLE {user} WITH LOGIN PASSWORD {pwd_lit}")
    print(f"updated role {user} password")

db_exists = psql("-tAc", f"SELECT 1 FROM pg_database WHERE datname = '{db}'")
if db_exists != "1":
    subprocess.check_call(["createdb", "-O", user, db])
    print(f"created database {db}")
else:
    psql("-c", f"ALTER DATABASE {db} OWNER TO {user}")
    print(f"database {db} already exists")

print(f"ensure-host-db: OK user={user} db={db} → 127.0.0.1:5432")
PY
