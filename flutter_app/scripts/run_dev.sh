#!/bin/bash
# ───────────────────────────────────────────
# Katasticho ERP — Run in DEV mode
# ───────────────────────────────────────────
# Connects to Spring Boot on localhost:8080
# (Android emulator uses 10.0.2.2 to reach host)
#
# Usage:
#   ./scripts/run_dev.sh                          # default (Android emulator)
#   ./scripts/run_dev.sh --device-id=chrome       # Chrome web
#   API_URL=http://192.168.1.5:8080 ./scripts/run_dev.sh  # physical device

set -euo pipefail
cd "$(dirname "$0")/.."

API_URL="${API_URL:-}"

ARGS=(
  "--dart-define=ENV=dev"
)

if [ -n "$API_URL" ]; then
  ARGS+=("--dart-define=API_BASE_URL=$API_URL")
fi

echo "┌──────────────────────────────────┐"
echo "│  Katasticho ERP — DEV Mode       │"
echo "│  API: ${API_URL:-http://10.0.2.2:8080 (default)}  │"
echo "└──────────────────────────────────┘"

flutter run "${ARGS[@]}" "$@"
