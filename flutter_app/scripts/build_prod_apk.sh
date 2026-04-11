#!/bin/bash
# ───────────────────────────────────────────
# Katasticho ERP — Build Production APK
# ───────────────────────────────────────────
# Outputs to: build/app/outputs/flutter-apk/app-release.apk
#
# Usage:
#   ./scripts/build_prod_apk.sh
#   SENTRY_DSN=https://xxx@sentry.io/123 ./scripts/build_prod_apk.sh

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
echo "│  Target: Android APK (release)   │"
echo "└──────────────────────────────────┘"

flutter build apk "${ARGS[@]}" "$@"

echo ""
echo "APK built at:"
echo "  build/app/outputs/flutter-apk/app-release.apk"
