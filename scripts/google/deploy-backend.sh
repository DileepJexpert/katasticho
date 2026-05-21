#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/katasticho/app}"

cd "$APP_DIR"
git pull origin main

set -a
. ./.env
set +a
sh scripts/validate-prod-env.sh

docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
curl -fsS http://localhost:8080/actuator/health
echo
