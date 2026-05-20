#!/usr/bin/env sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <backup-file.dump> [--clean]" >&2
  exit 1
fi

BACKUP_FILE="$1"
CLEAN="${2:-}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-katasticho}"
DB_USER="${DB_USER:-katasticho}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
  echo "pg_restore was not found. Install PostgreSQL client tools." >&2
  exit 1
fi

if [ -f "$BACKUP_FILE.sha256" ]; then
  expected="$(cat "$BACKUP_FILE.sha256" | tr -d '[:space:]')"
  actual="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    echo "Backup checksum mismatch. Expected $expected but got $actual." >&2
    exit 1
  fi
fi

export PGPASSWORD="${DB_PASSWORD:-}"

args="
  --host=$DB_HOST
  --port=$DB_PORT
  --username=$DB_USER
  --dbname=$DB_NAME
  --verbose
  --no-owner
  --no-privileges
"

if [ "$CLEAN" = "--clean" ]; then
  args="$args --clean --if-exists"
fi

# shellcheck disable=SC2086
pg_restore $args "$BACKUP_FILE"

unset PGPASSWORD

echo "Restore completed into database: $DB_NAME"
