#!/bin/bash
# ───────────────────────────────────────────
# Katasticho ERP — Build Production iOS
# ───────────────────────────────────────────
# Requires macOS with Xcode installed.
# Outputs to: build/ios/ipa/
#
# Usage:
#   ./scripts/build_prod_ios.sh

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
echo "│  Target: iOS (release)           │"
echo "└──────────────────────────────────┘"

flutter build ipa "${ARGS[@]}" "$@"

echo ""
echo "IPA built at: build/ios/ipa/"
