#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/katasticho/app}"
REPO_URL="${REPO_URL:-https://github.com/DileepJexpert/katasticho.git}"
APP_DOMAIN="${APP_DOMAIN:-app.katixo.com}"
API_DOMAIN="${API_DOMAIN:-api.katixo.com}"
APP_ROOT="${APP_ROOT:-/opt/katasticho/flutter-web}"

echo "Installing packages..."
sudo apt update
sudo apt install -y ca-certificates curl git postgresql-client ufw unzip debian-keyring debian-archive-keyring apt-transport-https gpg

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi
sudo usermod -aG docker "$USER" || true

echo "Configuring UFW..."
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo "Preparing app directory..."
sudo mkdir -p "$(dirname "$APP_DIR")"
sudo chown -R "$USER":"$USER" "$(dirname "$APP_DIR")"

if [ ! -d "$APP_DIR/.git" ]; then
  echo "Cloning repository. If prompted, use GitHub username and token."
  git clone "$REPO_URL" "$APP_DIR"
else
  echo "Repository already exists. Pulling latest main..."
  git -C "$APP_DIR" pull origin main
fi

cd "$APP_DIR"

if [ ! -f .env ]; then
  echo "Creating .env with generated local secrets..."
  DB_PASS="$(openssl rand -hex 32)"
  REDIS_PASS="$(openssl rand -hex 32)"
  JWT_SECRET_VALUE="$(openssl rand -hex 64)"

  cat > .env <<EOF
SPRING_PROFILES_ACTIVE=prod
DB_HOST=postgres
DB_PORT=5432
DB_NAME=katixo
DB_USER=katixo
DB_PASSWORD=$DB_PASS
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASS
JWT_SECRET=$JWT_SECRET_VALUE
JWT_ACCESS_EXPIRY=15
JWT_REFRESH_EXPIRY=7
ANTHROPIC_API_KEY=
MAIL_HOST=smtp.resend.com
MAIL_PORT=587
MAIL_USERNAME=resend
MAIL_PASSWORD=
MAIL_FROM=noreply@katixo.com
MAIL_FROM_NAME=Katixo
WHATSAPP_BUSINESS_API_KEY=
PORT=8080
CORS_DEV_MODE=false
CORS_ALLOWED_ORIGINS=https://$APP_DOMAIN,https://katixo.com
SENTRY_DSN=
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1
RATE_LIMIT_REQUESTS_PER_MINUTE=1000
RATE_LIMIT_AUTH_REQUESTS_PER_MINUTE=20
RATE_LIMIT_AI_REQUESTS_PER_MINUTE=10
API_BASE_URL=https://$API_DOMAIN
FLUTTER_SENTRY_DSN=
EOF
  chmod 600 .env
else
  echo ".env already exists; keeping existing secrets."
fi

echo "Validating production env..."
set -a
. ./.env
set +a
sh scripts/validate-prod-env.sh

echo "Starting backend..."
docker compose -f docker-compose.prod.yml up -d --build

echo "Installing Caddy repository..."
if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
fi
if [ ! -f /etc/apt/sources.list.d/caddy-stable.list ]; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
fi
sudo apt update
sudo apt install -y caddy

sudo mkdir -p "$APP_ROOT"
if [ ! -f "$APP_ROOT/index.html" ]; then
  echo '<h1>Katixo App Coming Soon</h1>' | sudo tee "$APP_ROOT/index.html" >/dev/null
fi

echo "Writing Caddyfile..."
sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$API_DOMAIN {
	reverse_proxy localhost:8080

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
	}
}

$APP_DOMAIN {
	root * $APP_ROOT
	encode zstd gzip
	try_files {path} /index.html
	file_server

	header /assets/* Cache-Control "public, max-age=31536000, immutable"
	header /flutter_service_worker.js Cache-Control "no-cache"
	header /index.html Cache-Control "no-cache"
}
EOF

sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy

echo "Health checks:"
docker compose -f docker-compose.prod.yml ps
curl -fsS "http://localhost:8080/actuator/health" || true
echo
echo "Provisioning complete."
echo "API: https://$API_DOMAIN/actuator/health"
echo "App: https://$APP_DOMAIN"
