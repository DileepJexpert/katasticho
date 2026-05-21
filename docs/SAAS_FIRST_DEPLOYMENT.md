# SaaS-First Deployment Plan

This is the recommended first deployment shape for the first 5-10 pilot customers.

## Product Shape

Katixo remains a cloud SaaS product:

- one backend API
- one PostgreSQL database
- one Redis cache
- one Flutter web app
- many organisations separated by `org_id`

POS offline mode can be added later as a local device cache and sync queue. The server remains the source of truth for invoices, stock, journals, GST, AI suggestions, and reports.

## Recommended First Server

Start with one VPS:

- Ubuntu 24.04 LTS
- 4 GB RAM
- 2 vCPU
- 80 GB disk
- Docker + Docker Compose
- Caddy reverse proxy

Use:

- `app.yourdomain.com` for Flutter web
- `api.yourdomain.com` for Spring Boot API

## Initial Setup

```bash
sudo apt update
sudo apt install -y ca-certificates curl git postgresql-client

curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
```

Clone and configure:

```bash
git clone https://github.com/DileepJexpert/katasticho.git
cd katasticho
cp .env.example .env
```

Set at minimum:

```env
SPRING_PROFILES_ACTIVE=prod
CORS_DEV_MODE=false
CORS_ALLOWED_ORIGINS=https://app.yourdomain.com
DB_PASSWORD=<strong-password>
REDIS_PASSWORD=<strong-password>
JWT_SECRET=<openssl-rand-base64-64>
MAIL_PASSWORD=<smtp-or-resend-key>
SENTRY_DSN=<optional-but-recommended>
```

Validate:

```bash
set -a
. ./.env
set +a
sh scripts/validate-prod-env.sh
```

Deploy:

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
curl http://localhost:8080/actuator/health
```

## Flutter Web

Build with the production API URL:

```bash
cd flutter_app
flutter build web --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Copy `flutter_app/build/web` to `/opt/katasticho/flutter-web` if serving from the same VPS with Caddy.

## Caddy

Use `deploy/caddy/Caddyfile.example` as a starting point:

```bash
sudo mkdir -p /etc/caddy /opt/katasticho/flutter-web
sudo cp deploy/caddy/Caddyfile.example /etc/caddy/Caddyfile
sudo sed -i 's/api.example.com/api.yourdomain.com/g; s/app.example.com/app.yourdomain.com/g; s/admin@example.com/you@yourdomain.com/g' /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

## Backups

Run a daily DB backup and copy it outside the server.

Manual backup:

```bash
set -a
. ./.env
set +a
OUTPUT_DIR=/opt/katasticho/backups sh scripts/backup-postgres.sh
```

Cron example:

```cron
15 1 * * * cd /opt/katasticho/app && set -a && . ./.env && set +a && OUTPUT_DIR=/opt/katasticho/backups sh scripts/backup-postgres.sh >> /var/log/katasticho-backup.log 2>&1
```

Copy backups to object storage or another machine. A backup that stays only on the same VPS is not enough.

Restore drill:

```bash
set -a
. ./.env
set +a
sh scripts/restore-postgres.sh /opt/katasticho/backups/<file>.dump --clean
```

Do one restore drill before giving access to the first real customer.

## First-Customer Go-Live Checklist

- [ ] Fresh server created.
- [ ] Firewall allows only SSH, HTTP, HTTPS.
- [ ] PostgreSQL and Redis are not exposed publicly.
- [ ] `.env` uses production secrets.
- [ ] `scripts/validate-prod-env.sh` passes.
- [ ] `docker compose -f docker-compose.prod.yml up -d --build` succeeds.
- [ ] `/actuator/health` is UP.
- [ ] Flutter web points to production API.
- [ ] CORS allows only production app URL.
- [ ] Backup script succeeds.
- [ ] Restore drill completed.
- [ ] Uptime monitor configured.
- [ ] Sentry or log monitoring configured.
- [ ] Test signup, login, invoice, payment, journal, report, and backup after deployment.

## What Not To Do

- Do not run `docker compose down -v` on production.
- Do not expose PostgreSQL or Redis ports to the internet.
- Do not let shop owners restore database backups themselves.
- Do not post accounting from an offline POS device. Offline sales must sync back to the server, where normal posting happens.
