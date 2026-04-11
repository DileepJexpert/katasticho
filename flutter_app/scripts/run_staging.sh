#!/bin/bash
# ───────────────────────────────────────────
# Katasticho ERP — Run in STAGING mode
# ───────────────────────────────────────────
# Connects to staging-api.katasticho.com

set -euo pipefail
cd "$(dirname "$0")/.."

echo "┌──────────────────────────────────┐"
echo "│  Katasticho ERP — STAGING Mode   │"
echo "│  API: staging-api.katasticho.com │"
echo "└──────────────────────────────────┘"

flutter run \
  --dart-define=ENV=staging \
  "$@"
