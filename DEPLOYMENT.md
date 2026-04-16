# Katasticho ERP — Deployment Guide

> **Stack:** Spring Boot 3.3.5 / Java 21 / PostgreSQL 16 / Redis 7 / Flutter 3.24  
> **Targets:** Railway (backend), Vercel (Flutter web), Android APK (mobile)

---

## Table of Contents

1. [Part A: Backend Deployment (Railway)](#part-a-backend-deployment-railway)
2. [Part B: Flutter Web Deployment (Vercel)](#part-b-flutter-web-deployment-vercel)
3. [Part C: Flutter Android APK](#part-c-flutter-android-apk)
4. [Part D: Landing Page](#part-d-landing-page)
5. [Part E: Domain + Email](#part-e-domain--email)
6. [Part F: Monitoring](#part-f-monitoring)
7. [Order of Execution](#order-of-execution)
8. [Environment Variables Reference](#environment-variables-reference)

---

## Part A: Backend Deployment (Railway)

### 1. Dockerfile

The `Dockerfile` at the project root uses a multi-stage build:

```dockerfile
# Stage 1: Maven build (full JDK)
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B
COPY src/ src/
RUN ./mvnw package -DskipTests -B && \
    mv target/katasticho-erp-*.jar target/app.jar

# Stage 2: Slim runtime (JRE only)
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /build/target/app.jar app.jar
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:InitialRAMPercentage=50.0 \
               -Djava.security.egd=file:/dev/./urandom"
EXPOSE 8080
USER app
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 2. Test Locally

```bash
# Build image
docker build -t katasticho-erp .

# Run with local Postgres + Redis from docker-compose.yml
docker compose up -d postgres redis
docker run --rm -p 8080:8080 \
  --network katasticho_default \
  -e DB_HOST=postgres -e DB_PORT=5432 \
  -e DB_NAME=katasticho -e DB_USER=katasticho -e DB_PASSWORD=katasticho \
  -e REDIS_HOST=redis -e REDIS_PORT=6379 \
  -e JWT_SECRET="dev-secret-key-at-least-256-bits-long-for-testing-only" \
  -e SPRING_PROFILES_ACTIVE=prod \
  katasticho-erp

# Verify
curl http://localhost:8080/actuator/health
```

### 3. Production Docker Compose

For self-hosted deployments, use `docker-compose.prod.yml`:

```bash
cp .env.example .env
# Edit .env with production values
docker compose -f docker-compose.prod.yml up -d
```

### 4. Railway Configuration

The `railway.toml` at the project root configures Railway's build pipeline:

```toml
[build]
builder = "dockerfile"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "java $JAVA_OPTS -jar app.jar"
healthcheckPath = "/actuator/health"
healthcheckTimeout = 60
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 5
numReplicas = 1
```

**Railway setup steps:**

1. Create a new project on [railway.app](https://railway.app)
2. Connect the GitHub repository (`dileepjexpert/katasticho`)
3. Add a **PostgreSQL** plugin → copies `DATABASE_URL` automatically
4. Add a **Redis** plugin → copies `REDIS_URL` automatically
5. Set environment variables in the Railway dashboard:

| Variable | Value |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `DB_HOST` | From Railway Postgres plugin |
| `DB_PORT` | From Railway Postgres plugin |
| `DB_NAME` | From Railway Postgres plugin |
| `DB_USER` | From Railway Postgres plugin |
| `DB_PASSWORD` | From Railway Postgres plugin |
| `REDIS_HOST` | From Railway Redis plugin |
| `REDIS_PORT` | From Railway Redis plugin |
| `JWT_SECRET` | `openssl rand -base64 64` |
| `ANTHROPIC_API_KEY` | Your Anthropic key |
| `MAIL_HOST` | `smtp.resend.com` |
| `MAIL_PORT` | `587` |
| `MAIL_USERNAME` | `resend` |
| `MAIL_PASSWORD` | Your Resend API key |
| `PORT` | `8080` |

> **Note:** Railway injects `DATABASE_URL` and `REDIS_URL` as connection strings.
> Our app uses individual `DB_HOST/DB_PORT/...` env vars, so either:
> - Set them individually from the plugin values, OR
> - Parse `DATABASE_URL` in a custom start script

6. Railway auto-deploys on push to `main`. Flyway migrations run on startup.

### 5. Production application.yml Profile

The existing `application.yml` already has a `prod` profile. Key production behaviors:

- **Flyway:** Runs migrations on startup (`spring.flyway.enabled: true`)
- **JPA:** `ddl-auto: validate` — no schema changes at runtime
- **Logging:** INFO level (no DEBUG SQL)
- **Mail:** Resend SMTP with TLS enabled
- **Actuator:** Only `health`, `info`, `metrics` exposed

**Additional hardening** (optional — add to the prod profile):

```yaml
---
spring:
  config:
    activate:
      on-profile: prod
  # ... existing prod config ...

server:
  forward-headers-strategy: framework    # trust Railway's proxy headers
  error:
    include-stacktrace: never
    include-message: never
```

---

## Part B: Flutter Web Deployment (Vercel)

### 1. Build Command

```bash
cd flutter_app
flutter build web --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.katasticho.com
```

### 2. Vercel Configuration

The `flutter_app/vercel.json` handles SPA routing and caching:

```json
{
  "buildCommand": "flutter build web --release --dart-define=ENV=prod --dart-define=API_BASE_URL=$API_BASE_URL",
  "outputDirectory": "build/web",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    },
    {
      "source": "/flutter_service_worker.js",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache" }
      ]
    },
    {
      "source": "/index.html",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache" }
      ]
    }
  ]
}
```

### 3. Vercel Setup Steps

1. Go to [vercel.com](https://vercel.com) → Import Git Repository
2. Set **Root Directory** to `flutter_app`
3. Framework Preset: **Other**
4. Add environment variable:
   - `API_BASE_URL` = `https://api.katasticho.com`
5. Vercel will install Flutter via the `installCommand` in `vercel.json`
6. Assign custom domain: `app.katasticho.com`

> **Alternative (pre-built deploy):** Build locally and deploy the static output:
> ```bash
> cd flutter_app
> flutter build web --release \
>   --dart-define=ENV=prod \
>   --dart-define=API_BASE_URL=https://api.katasticho.com
> cd build/web
> npx vercel --prod
> ```

### 4. CORS Configuration

Ensure the backend allows the Flutter web domain. In the Spring Boot CORS config, add `app.katasticho.com` to allowed origins for production:

```java
// In your WebMvcConfigurer or SecurityFilterChain:
.cors(cors -> cors.configurationSource(request -> {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of(
        "https://app.katasticho.com",
        "https://katasticho.com"
    ));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "PATCH"));
    config.setAllowedHeaders(List.of("*"));
    config.setAllowCredentials(true);
    return config;
}))
```

---

## Part C: Flutter Android APK

### 1. Generate Signing Key

```bash
keytool -genkey -v \
  -keystore katasticho-release.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias katasticho \
  -storepass <YOUR_STORE_PASSWORD> \
  -keypass <YOUR_KEY_PASSWORD> \
  -dname "CN=Katasticho, OU=Engineering, O=Katasticho, L=India, C=IN"
```

Move the keystore to a safe location (NOT committed to git).

### 2. Create `flutter_app/android/key.properties`

```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=katasticho
storeFile=/path/to/katasticho-release.jks
```

> Add `key.properties` and `*.jks` to `.gitignore`

### 3. Configure `android/app/build.gradle`

Add the signing config above the `buildTypes` block:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 4. Build APK

```bash
cd flutter_app

# Split per ABI (recommended — smaller APKs)
flutter build apk --release --split-per-abi \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.katasticho.com

# Output at:
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk   (~15 MB)
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk     (~16 MB)
#   build/app/outputs/flutter-apk/app-x86_64-release.apk        (~17 MB)

# OR: Universal fat APK
flutter build apk --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.katasticho.com
```

### 5. App Assets

| Asset | Spec |
|---|---|
| App Icon | 1024x1024 PNG, placed in `android/app/src/main/res/mipmap-*` |
| Splash Screen | Use `flutter_native_splash` package |
| App Name | Set in `android/app/src/main/AndroidManifest.xml`: `android:label="Katasticho"` |
| Package Name | `com.katasticho.erp` |

Generate icons with [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons):

```yaml
# flutter_app/pubspec.yaml — add under dev_dependencies
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#0284C7"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

```bash
dart run flutter_launcher_icons
```

---

## Part D: Landing Page

### Option 1: Static HTML + Tailwind (Simplest)

Create a `website/` directory or separate repo `katasticho-website`:

```
website/
├── index.html
├── styles.css        # Tailwind CDN
└── assets/
    ├── logo.svg
    └── screenshots/
```

**Key sections for `index.html`:**

- **Hero:** "Accounting + Inventory for Indian MSMEs"
- **Badge:** "Free forever for small businesses"
- **Features grid:** Invoicing, Bills/AP, Inventory, GST, AI Reports, Multi-branch
- **Screenshots carousel** from the app
- **CTA buttons:** `[Download Android APK]` `[Launch Web App →]`
- **Contact form:** Simple mailto or Google Forms embed
- **Footer:** "Made in India" + social links

Deploy to Vercel:

```bash
cd website
npx vercel --prod
# Assign domain: katasticho.com
```

### Option 2: Next.js Static Export

```bash
npx create-next-app@latest katasticho-website --typescript --tailwind
cd katasticho-website
# Build as static export
# next.config.js: output: 'export'
npm run build  # generates /out
npx vercel --prod
```

---

## Part E: Domain + Email

### 1. Register Domain

Register `katasticho.com` on GoDaddy, Namecheap, or Cloudflare Registrar.

### 2. DNS Configuration

| Record | Host | Target | Service |
|---|---|---|---|
| A / CNAME | `@` (root) | Vercel IP / `cname.vercel-dns.com` | Landing page |
| CNAME | `app` | `cname.vercel-dns.com` | Flutter web app |
| CNAME | `api` | `<project>.up.railway.app` | Spring Boot backend |

**Vercel domains:**
```bash
# Landing page
npx vercel domains add katasticho.com

# Flutter web app
npx vercel domains add app.katasticho.com
```

**Railway custom domain:**
1. Railway Dashboard → Settings → Custom Domain
2. Add `api.katasticho.com`
3. Railway provides a CNAME target — add it to DNS

### 3. Email Setup

**Option A: Zoho Mail (free tier — up to 5 users)**
1. Sign up at [zoho.com/mail](https://www.zoho.com/mail/)
2. Verify domain with TXT record
3. Add MX records:
   - `mx.zoho.com` (priority 10)
   - `mx2.zoho.com` (priority 20)
4. Create: `hello@katasticho.com`

**Option B: Google Workspace ($6/user/month)**
1. Sign up at [workspace.google.com](https://workspace.google.com)
2. Verify domain, add MX records
3. Create: `hello@katasticho.com`, `support@katasticho.com`

**SPF + DKIM + DMARC records** (for deliverability):

```
# SPF (TXT record on @)
v=spf1 include:zoho.com ~all

# DMARC (TXT record on _dmarc)
v=DMARC1; p=quarantine; rua=mailto:hello@katasticho.com
```

---

## Part F: Monitoring

### 1. Sentry (Error Tracking)

**Backend — Spring Boot:**

Add to `pom.xml`:
```xml
<dependency>
    <groupId>io.sentry</groupId>
    <artifactId>sentry-spring-boot-starter-jakarta</artifactId>
    <version>7.14.0</version>
</dependency>
```

Add to `application.yml` (prod profile):
```yaml
sentry:
  dsn: ${SENTRY_DSN:}
  environment: production
  traces-sample-rate: 0.1
```

**Flutter:**

Add to `pubspec.yaml`:
```yaml
dependencies:
  sentry_flutter: ^8.9.0
```

Initialize in `main.dart`:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = EnvConfig.sentryDsn;
      options.environment = EnvConfig.environment.name;
      options.tracesSampleRate = 0.1;
    },
    appRunner: () => runApp(const ProviderScope(child: KatastichoApp())),
  );
}
```

### 2. Railway Logs

Railway provides built-in log streaming:
- View logs: Railway Dashboard → Deployments → Logs
- CLI: `railway logs --follow`
- Log drain (optional): Forward to Datadog/Grafana

### 3. Uptime Monitoring — UptimeRobot

1. Sign up at [uptimerobot.com](https://uptimerobot.com) (free tier)
2. Add monitors:

| Monitor | URL | Interval |
|---|---|---|
| Backend Health | `https://api.katasticho.com/actuator/health` | 5 min |
| Flutter Web | `https://app.katasticho.com` | 5 min |
| Landing Page | `https://katasticho.com` | 5 min |

3. Configure alerts: Email to `hello@katasticho.com`

### 4. Spring Boot Actuator Endpoints

Already configured — available at `/actuator/*`:

| Endpoint | Purpose |
|---|---|
| `/actuator/health` | Liveness + readiness (DB, Redis) |
| `/actuator/info` | App metadata |
| `/actuator/metrics` | JVM, HTTP, DB pool metrics |

---

## Order of Execution

| # | Task | Time Estimate |
|---|---|---|
| 1 | Build Docker image + test locally | Half day |
| 2 | Deploy backend to Railway | 1 hour |
| 3 | Deploy Flutter web to Vercel | 1 hour |
| 4 | Domain + DNS setup | 30 min (+ propagation wait) |
| 5 | Build Android APK | 1 hour |
| 6 | Smoke test all features on deployed version | 1 hour |
| 7 | Create landing page | Half day |
| 8 | Monitoring setup (Sentry + UptimeRobot) | 30 min |

---

## Environment Variables Reference

All variables documented in `.env.example`:

| Variable | Required | Default | Description |
|---|---|---|---|
| `SPRING_PROFILES_ACTIVE` | Yes | — | `prod` for production |
| `DB_HOST` | Yes | `localhost` | PostgreSQL host |
| `DB_PORT` | Yes | `5432` | PostgreSQL port |
| `DB_NAME` | Yes | `katasticho` | Database name |
| `DB_USER` | Yes | `katasticho` | Database user |
| `DB_PASSWORD` | **Yes** | — | Database password |
| `REDIS_HOST` | Yes | `localhost` | Redis host |
| `REDIS_PORT` | Yes | `6379` | Redis port |
| `REDIS_PASSWORD` | No | — | Redis password |
| `JWT_SECRET` | **Yes** | — | Min 256-bit secret |
| `JWT_ACCESS_EXPIRY` | No | `15` | Access token TTL (minutes) |
| `JWT_REFRESH_EXPIRY` | No | `7` | Refresh token TTL (days) |
| `ANTHROPIC_API_KEY` | No | — | Enables AI features |
| `MAIL_HOST` | No | `smtp.resend.com` | SMTP server |
| `MAIL_PORT` | No | `587` | SMTP port |
| `MAIL_USERNAME` | No | `resend` | SMTP user |
| `MAIL_PASSWORD` | No | — | SMTP password / API key |
| `WHATSAPP_BUSINESS_API_KEY` | No | — | Future WhatsApp integration |
| `PORT` | No | `8080` | Server port |
| `API_BASE_URL` | Build-time | — | Flutter web API target |
| `SENTRY_DSN` | No | — | Sentry error tracking |

---

## Quick Start Checklist

- [ ] Copy `.env.example` → `.env` and fill in secrets
- [ ] `docker build -t katasticho-erp .` — verify image builds
- [ ] `docker compose -f docker-compose.prod.yml up -d` — test locally
- [ ] `curl http://localhost:8080/actuator/health` — confirm `{"status":"UP"}`
- [ ] Push to GitHub → Railway auto-deploys
- [ ] `cd flutter_app && flutter build web --release` → deploy to Vercel
- [ ] Configure DNS for `api.katasticho.com` and `app.katasticho.com`
- [ ] Build Android APK with release signing
- [ ] Set up UptimeRobot monitors
- [ ] Ship it
