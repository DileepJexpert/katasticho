#!/bin/bash
# ───────────────────────────────────────────
# Katasticho ERP — Build Production App Bundle (Play Store)
# ───────────────────────────────────────────
# Outputs to: build/app/outputs/bundle/release/app-release.aab
#
# Usage:
#   ./scripts/build_prod_appbundle.sh

set -euo pipefail
cd "$(dirname "$0")/.."

SENTRY_DSN="${SENTRY_DSN:-}"

ARGS=(
  "--release"
  "--dart-define=ENV=prod"
)

if [ -n "$SENTRY_DSN" ]; then
  ARGS+=("--dart-define=SENTRY_DSN=$SENTRY_DSN")
fi

echo "┌──────────────────────────────────┐"
echo "│  Katasticho ERP — PROD Build     │"
echo "│  Target: App Bundle (Play Store) │"
echo "└──────────────────────────────────┘"

flutter build appbundle "${ARGS[@]}" "$@"

echo ""
echo "App Bundle built at:"
echo "  build/app/outputs/bundle/release/app-release.aab"
