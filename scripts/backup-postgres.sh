#!/usr/bin/env sh
set -eu

OUTPUT_DIR="${OUTPUT_DIR:-./backups}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-katasticho}"
DB_USER="${DB_USER:-katasticho}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump was not found. Install PostgreSQL client tools." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

timestamp="$(date -u +%Y%m%d-%H%M%S)"
target="$OUTPUT_DIR/katasticho-$DB_NAME-$timestamp.dump"

export PGPASSWORD="${DB_PASSWORD:-}"

pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --format=custom \
  --blobs \
  --verbose \
  --file="$target" \
  "$DB_NAME"

sha256sum "$target" | awk '{print $1}' > "$target.sha256"

find "$OUTPUT_DIR" -name "katasticho-$DB_NAME-*.dump" -type f -mtime +"$RETENTION_DAYS" -delete
find "$OUTPUT_DIR" -name "katasticho-$DB_NAME-*.dump.sha256" -type f -mtime +"$RETENTION_DAYS" -delete

unset PGPASSWORD

echo "Backup created: $target"
echo "SHA256: $(cat "$target.sha256")"
