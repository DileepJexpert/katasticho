#!/usr/bin/env bash
set -euo pipefail

API_DOMAIN="${API_DOMAIN:-api.katixo.com}"
APP_DOMAIN="${APP_DOMAIN:-app.katixo.com}"
APP_DIR="${APP_DIR:-/opt/katasticho/app}"

if [ -d "$APP_DIR" ]; then
  cd "$APP_DIR"
  docker compose -f docker-compose.prod.yml ps || true
fi

echo "Local API:"
curl -fsS http://localhost:8080/actuator/health || true
echo

echo "Public API:"
curl -fsS "https://$API_DOMAIN/actuator/health" || true
echo

echo "Public app headers:"
curl -I "https://$APP_DOMAIN" || true
