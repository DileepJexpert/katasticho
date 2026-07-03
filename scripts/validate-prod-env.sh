#!/usr/bin/env sh
set -eu

missing=""

require_var() {
  name="$1"
  value="$(eval "printf '%s' \"\${$name:-}\"")"
  if [ -z "$value" ]; then
    missing="$missing $name"
  fi
}

require_var DB_PASSWORD
require_var JWT_SECRET
require_var JWT_PLATFORM_ADMIN_SECRET

if [ -n "$missing" ]; then
  echo "Missing required production environment variables:$missing" >&2
  exit 1
fi

if [ "${SPRING_PROFILES_ACTIVE:-}" != "prod" ]; then
  echo "SPRING_PROFILES_ACTIVE should be 'prod' for production deployments." >&2
  exit 1
fi

if [ "${CORS_DEV_MODE:-false}" != "false" ]; then
  echo "CORS_DEV_MODE must be false in production." >&2
  exit 1
fi

if [ "${JWT_SECRET:-}" = "katasticho-dev-secret-key-change-in-production-must-be-at-least-256-bits" ]; then
  echo "JWT_SECRET is still using the development default." >&2
  exit 1
fi

secret_len=$(printf '%s' "$JWT_SECRET" | wc -c | tr -d ' ')
if [ "$secret_len" -lt 32 ]; then
  echo "JWT_SECRET is too short. Generate one with: openssl rand -base64 64" >&2
  exit 1
fi

platform_secret_len=$(printf '%s' "$JWT_PLATFORM_ADMIN_SECRET" | wc -c | tr -d ' ')
if [ "$platform_secret_len" -lt 32 ]; then
  echo "JWT_PLATFORM_ADMIN_SECRET is too short. Generate one with: openssl rand -base64 64" >&2
  exit 1
fi

case "${CORS_ALLOWED_ORIGINS:-}" in
  *localhost*|*127.0.0.1*)
    echo "CORS_ALLOWED_ORIGINS contains localhost/127.0.0.1. Remove dev origins before production." >&2
    exit 1
    ;;
esac

echo "Production environment validation passed."
