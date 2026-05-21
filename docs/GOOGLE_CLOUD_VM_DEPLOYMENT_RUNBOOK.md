# Google Cloud VM Deployment Runbook

This runbook documents the deployment path used for the first Katixo/Katasticho beta server on Google Cloud Compute Engine.

Use this when you delete/recreate the VM or need to deploy the same stack again.

## Target Architecture

```text
Cloudflare DNS
+-- app.katixo.com  -> Google VM -> Caddy -> Flutter web
`-- api.katixo.com  -> Google VM -> Caddy -> Spring Boot on localhost:8080

Google VM
+-- Caddy
+-- Docker Compose
+-- Spring Boot API container
+-- PostgreSQL container
`-- Redis container
```

Root domain `katixo.com` can stay on Cloudflare Pages. Only `app` and `api` need to point to the VM.

## 1. Reserve Or Reuse Static IP

If the static IP already exists, list it:

```bash
gcloud compute addresses list \
  --regions=asia-south1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --filter="name:katixo-static-ip"
```

Expected:

```text
ADDRESS/RANGE: 34.93.34.111
STATUS: RESERVED
```

If you need to create it:

```bash
gcloud compute addresses create katixo-static-ip \
  --project=project-e70d88f7-8342-43d8-a26 \
  --region=asia-south1
```

## 2. Create VM

For the current low-cost beta setup:

```bash
gcloud compute instances create katixo-beta-1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a \
  --machine-type=e2-standard-2 \
  --network-interface=address=34.93.34.111,network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --tags=http-server,https-server \
  --create-disk=auto-delete=yes,boot=yes,device-name=katixo-beta-1,image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64,mode=rw,size=35,type=pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=goog-ec-src=vm_add-gcloud \
  --reservation-affinity=any
```

Important:

- Include `address=34.93.34.111`. If omitted, Google assigns a temporary IP and DNS will not point to the VM.
- `35 GB` is enough for an early beta but keep backups small and clean Docker cache when needed.
- The warning that disk size is larger than image size is normal.

Verify:

```bash
gcloud compute instances list \
  --project=project-e70d88f7-8342-43d8-a26
```

Expected:

```text
NAME: katixo-beta-1
ZONE: asia-south1-a
EXTERNAL_IP: 34.93.34.111
STATUS: RUNNING
```

## 3. SSH Into VM

From Cloud Shell:

```bash
gcloud compute ssh katixo-beta-1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

If SSH key is created, accept and enter/passphrase as needed.

When prompt shows this, you are inside VM:

```text
todileepmaurya@katixo-beta-1:~$
```

Do not run `gcloud compute ssh` again from inside the VM. If you do, you may see:

```text
Request had insufficient authentication scopes
```

That is harmless; it just means you tried to use Google Cloud APIs from the VM.

## 4. Install Base Tools And Docker

Inside VM:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git postgresql-client ufw nano
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
```

Exit and reconnect so Docker group permissions apply:

```bash
exit
```

Then from Cloud Shell:

```bash
gcloud compute ssh katixo-beta-1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

Verify:

```bash
docker --version
df -h
```

Expected disk is roughly:

```text
/dev/root  33G  ...
```

## 5. Configure VM Firewall

Inside VM:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
sudo ufw status
```

Expected:

```text
OpenSSH ALLOW
80      ALLOW
443     ALLOW
```

Google Cloud firewall also needs HTTP/HTTPS allowed. Creating the VM with `--tags=http-server,https-server` usually matches default firewall rules. If HTTP/HTTPS do not work, create firewall rules in Google Cloud.

## 6. Clone Private GitHub Repo

Inside VM:

```bash
sudo mkdir -p /opt/katasticho
sudo chown -R "$USER":"$USER" /opt/katasticho
cd /opt/katasticho
git clone https://github.com/DileepJexpert/katasticho.git app
cd app
```

If Git asks for credentials:

```text
Username: DileepJexpert
Password: GitHub personal access token
```

Do not use your GitHub password. GitHub requires a token.

Token creation:

1. Open `https://github.com/settings/tokens`
2. Create fine-grained token.
3. Select repository `DileepJexpert/katasticho`.
4. Give `Contents: Read-only`.
5. Copy token immediately; GitHub shows it only once.

After one successful clone/pull, you can save credentials:

```bash
git config --global credential.helper store
git pull origin main
```

## 7. Create Production `.env` Safely

Do not manually paste multiline base64 secrets into `.env`; base64 can wrap and break shell parsing.

Use hex secrets instead:

```bash
cd /opt/katasticho/app

DB_PASS=$(openssl rand -hex 32)
REDIS_PASS=$(openssl rand -hex 32)
JWT_SECRET_VALUE=$(openssl rand -hex 64)

cat > .env <<EOF
SPRING_PROFILES_ACTIVE=prod
DB_HOST=postgres
DB_PORT=5432
DB_NAME=katasticho
DB_USER=katasticho
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
CORS_ALLOWED_ORIGINS=https://app.katixo.com,https://katixo.com
SENTRY_DSN=
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1
RATE_LIMIT_REQUESTS_PER_MINUTE=1000
RATE_LIMIT_AUTH_REQUESTS_PER_MINUTE=20
RATE_LIMIT_AI_REQUESTS_PER_MINUTE=10
API_BASE_URL=https://api.katixo.com
FLUTTER_SENTRY_DSN=
EOF

chmod 600 .env
```

Verify clean file:

```bash
grep -n "^[A-Z_]*=" .env
```

Validate:

```bash
set -a
. ./.env
set +a
sh scripts/validate-prod-env.sh
```

Expected:

```text
Production environment validation passed.
```

## 8. Start Backend

```bash
cd /opt/katasticho/app
docker compose -f docker-compose.prod.yml up -d --build
```

This can take a few minutes on first build.

Check:

```bash
docker compose -f docker-compose.prod.yml ps
curl http://localhost:8080/actuator/health
```

Expected:

```text
katasticho-app          Up ... (healthy)
katasticho-db-prod      Up ... (healthy)
katasticho-redis-prod   Up ... (healthy)
{"status":"UP"}
```

If health is `DOWN`, inspect logs:

```bash
docker compose -f docker-compose.prod.yml logs app | grep -i -E "ERROR|Caused by|Exception|DOWN|redis|database|health" | tail -80
```

Known issue fixed in repo:

- Mail health used to fail when `MAIL_PASSWORD` was empty.
- Current config disables mail health by default unless `MANAGEMENT_HEALTH_MAIL_ENABLED=true`.

## 9. Cloudflare DNS

Keep root domain on Cloudflare Pages if desired.

Create only:

```text
Type  Name  Value         Proxy
A     api   34.93.34.111  DNS only
A     app   34.93.34.111  DNS only
```

Do not delete existing:

```text
katixo.com -> katixo.pages.dev
www
```

Verify DNS:

```bash
nslookup api.katixo.com
nslookup app.katixo.com
```

Both should resolve to:

```text
34.93.34.111
```

## 10. Install And Configure Caddy

Inside VM:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

Create a temporary frontend page:

```bash
sudo mkdir -p /opt/katasticho/flutter-web
echo '<h1>Katixo App Coming Soon</h1>' | sudo tee /opt/katasticho/flutter-web/index.html
```

Write Caddy config:

```bash
sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
api.katixo.com {
	reverse_proxy localhost:8080

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
	}
}

app.katixo.com {
	root * /opt/katasticho/flutter-web
	encode zstd gzip
	try_files {path} /index.html
	file_server

	header /assets/* Cache-Control "public, max-age=31536000, immutable"
	header /flutter_service_worker.js Cache-Control "no-cache"
	header /index.html Cache-Control "no-cache"
}
EOF
```

Validate and reload:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager
```

Test API:

```bash
curl -I https://api.katixo.com/actuator/health
curl https://api.katixo.com/actuator/health
curl -I https://app.katixo.com
```

Expected:

```text
HTTP/2 200
{"status":"UP"}
HTTP/2 200
```

## 11. Build Flutter Web Locally On Windows

On Windows PowerShell:

```powershell
cd C:\dileepkm\Learning\erp-system\katasticho\flutter_app

flutter build web --release `
  --dart-define=ENV=prod `
  --dart-define=API_BASE_URL=https://api.katixo.com
```

Create zip:

```powershell
Compress-Archive -Path .\build\web\* -DestinationPath .\flutter-web.zip -Force
```

Windows `scp` may fail with:

```text
Permission denied (publickey)
```

That happens because Google SSH key exists in Cloud Shell, not Windows. Use Cloud Shell upload.

## 12. Upload Flutter Zip Through Cloud Shell

In Cloud Shell:

1. Click Cloud Shell upload.
2. Upload `flutter-web.zip`.
3. It lands in `/home/todileepmaurya`.

Verify in Cloud Shell:

```bash
ls -lh ~/flutter-web.zip
```

Copy to VM:

```bash
gcloud compute scp ~/flutter-web.zip katixo-beta-1:/tmp/flutter-web.zip \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

SSH into VM:

```bash
gcloud compute ssh katixo-beta-1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

Deploy frontend on VM:

```bash
sudo apt install -y unzip
rm -rf /tmp/flutter-web
mkdir -p /tmp/flutter-web
unzip -o /tmp/flutter-web.zip -d /tmp/flutter-web

sudo rm -rf /opt/katasticho/flutter-web/*
sudo cp -r /tmp/flutter-web/* /opt/katasticho/flutter-web/
sudo chown -R caddy:caddy /opt/katasticho/flutter-web
sudo systemctl reload caddy
```

Test:

```bash
curl -I https://app.katixo.com
```

Open:

```text
https://app.katixo.com
```

## 13. First Backup

After deployment:

```bash
cd /opt/katasticho/app
set -a
. ./.env
set +a
OUTPUT_DIR=/opt/katasticho/backups sh scripts/backup-postgres.sh
ls -lh /opt/katasticho/backups
```

Copy backups outside the VM. A backup stored only on the same VM is not enough.

## 14. Common Mistakes From First Deployment

### Mistake: Running `gcloud compute ssh` inside VM

If prompt contains `@katixo-beta-1`, you are already inside VM.

Use `exit` to return to Cloud Shell.

### Mistake: Accidentally typing wrong command like `exi`

Be careful: Cloud Shell may autocomplete or interpret partial commands. We accidentally saw a delete prompt. Always read delete prompts and answer `n` unless intentionally deleting.

### Mistake: Static IP not attached

If VM external IP is not `34.93.34.111`, DNS will point to the wrong server.

Delete/recreate or attach the static IP before continuing.

### Mistake: Private GitHub clone asks username

Use GitHub token, not password.

### Mistake: Multiline base64 breaks `.env`

Use `openssl rand -hex`, not base64, for values written through shell heredoc.

### Mistake: Backend health DOWN because optional mail missing

Mail health is disabled by default now. If you enable mail health, set `MAIL_PASSWORD`.

### Mistake: Local Windows `gcloud` missing

Use Cloud Shell for `gcloud compute scp`, or install Google Cloud CLI locally.

### Mistake: Windows `scp` permission denied

Use Cloud Shell upload + `gcloud compute scp`.

## 15. If VM Is Deleted

If the VM is deleted, because boot disk is `auto-delete=yes`, you must redo:

1. Create VM with static IP.
2. Install Docker/tools.
3. Configure firewall.
4. Clone repo.
5. Recreate `.env`.
6. Start Docker Compose.
7. Install/configure Caddy.
8. Reupload Flutter build.
9. Restore database backup if real data existed.

If VM is only restarted or stopped/started, you do not redo setup. Docker containers restart automatically.
