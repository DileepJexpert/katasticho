#!/usr/bin/env bash
# Dev-phase database reset.
#
# During development we do NOT write ALTER migrations: schema changes are
# edited directly into db/migration/V1__baseline_schema.sql (and seed data
# into V2__reference_data.sql), then the database volume is recreated and
# Flyway rebuilds everything from the baseline on next app start.
#
# Usage: ./scripts/reset-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Stopping containers and deleting volumes (postgres data will be wiped)..."
docker compose down -v

echo "Starting fresh postgres + redis..."
docker compose up -d postgres redis

echo "Waiting for postgres to be healthy..."
until docker compose exec -T postgres pg_isready -U katasticho > /dev/null 2>&1; do
  sleep 1
done

echo "Done. Start the app (mvn spring-boot:run) — Flyway will apply V1+V2 from scratch."
