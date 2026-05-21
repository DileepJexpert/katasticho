#!/usr/bin/env bash
set -euo pipefail

ZIP_FILE="${1:-/tmp/flutter-web.zip}"
APP_ROOT="${APP_ROOT:-/opt/katasticho/flutter-web}"

if [ ! -f "$ZIP_FILE" ]; then
  echo "Flutter web zip not found: $ZIP_FILE" >&2
  echo "Copy it first, for example:" >&2
  echo "  gcloud compute scp ~/flutter-web.zip katixo-beta-1:/tmp/flutter-web.zip --zone=asia-south1-a" >&2
  exit 1
fi

sudo apt install -y unzip
rm -rf /tmp/flutter-web
mkdir -p /tmp/flutter-web
unzip -o "$ZIP_FILE" -d /tmp/flutter-web

sudo mkdir -p "$APP_ROOT"
sudo rm -rf "$APP_ROOT"/*
sudo cp -r /tmp/flutter-web/* "$APP_ROOT"/
sudo chown -R caddy:caddy "$APP_ROOT"
sudo systemctl reload caddy

echo "Flutter web deployed to $APP_ROOT"
