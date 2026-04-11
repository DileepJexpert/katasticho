# Katasticho ERP — Flutter App Setup Guide

## Prerequisites

- **Flutter SDK** >= 3.3.0 ([install](https://docs.flutter.dev/get-started/install))
- **Android Studio** (for Android) or **Xcode** (for iOS)
- **Java 21** + **Spring Boot backend** running (see `../README.md`)
- **PostgreSQL 16** running with schema migrated

```bash
flutter doctor   # Verify installation
```

---

## 1. Local Development Setup

### Step 1: Install dependencies

```bash
cd flutter_app
flutter pub get
```

### Step 2: Start the Spring Boot backend

```bash
# In a separate terminal, from project root:
cd ..
mvn spring-boot:run
# Backend starts at http://localhost:8080
```

### Step 3: Run the Flutter app

**Android Emulator** (default — uses `10.0.2.2` to reach host machine):
```bash
flutter run --dart-define=ENV=dev
# or
./scripts/run_dev.sh
```

**Chrome / Web:**
```bash
flutter run -d chrome --dart-define=ENV=dev
```

**Physical Android device** (replace with your machine's LAN IP):
```bash
flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://192.168.1.100:8080
# or
API_URL=http://192.168.1.100:8080 ./scripts/run_dev.sh
```

**iOS Simulator:**
```bash
flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://localhost:8080
```

### VS Code Quick Launch

Open `flutter_app/` in VS Code. Pre-configured launch profiles are in `.vscode/launch.json`:

| Profile                  | Description                        |
|--------------------------|------------------------------------|
| DEV (local backend)      | Android emulator → localhost:8080  |
| DEV (custom API URL)     | Change IP in launch.json           |
| Staging                  | Connects to staging API            |
| Production (debug)       | Prod config, debug mode            |
| Production (release)     | Prod config, release mode          |

---

## 2. Environment Configuration

All configuration is injected at build time via `--dart-define`. No `.env` files needed.

### Available `--dart-define` flags

| Flag            | Default (DEV)              | Description                      |
|-----------------|----------------------------|----------------------------------|
| `ENV`           | `dev`                      | `dev`, `staging`, or `prod`      |
| `API_BASE_URL`  | `http://10.0.2.2:8080`    | Override the API base URL        |
| `SENTRY_DSN`    | _(empty)_                  | Sentry error tracking DSN        |

### Environment defaults

| Setting            | DEV                      | Staging                           | Production                    |
|--------------------|--------------------------|-----------------------------------|-------------------------------|
| API Base URL       | `http://10.0.2.2:8080`  | `https://staging-api.katasticho.com` | `https://api.katasticho.com` |
| Connect Timeout    | 30s                      | 15s                               | 15s                           |
| Receive Timeout    | 60s                      | 30s                               | 30s                           |
| Debug Banner       | Yes                      | No                                | No                            |
| HTTP Logging       | Yes                      | Yes                               | No                            |
| Perf Monitoring    | No                       | Yes                               | Yes                           |
| App Name           | Katasticho DEV           | Katasticho STG                    | Katasticho ERP                |

---

## 3. Production Build

### Android APK (direct install / testing)

```bash
flutter build apk --release --dart-define=ENV=prod
# or
./scripts/build_prod_apk.sh
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Google Play Store)

```bash
flutter build appbundle --release --dart-define=ENV=prod
# or
./scripts/build_prod_appbundle.sh
```

Output: `build/app/outputs/bundle/release/app-release.aab`

> **Note:** For Play Store, you need to configure signing in
> `android/app/build.gradle` with your keystore. See
> [Flutter deployment docs](https://docs.flutter.dev/deployment/android).

### iOS (App Store)

```bash
flutter build ipa --release --dart-define=ENV=prod
# or
./scripts/build_prod_ios.sh
```

Output: `build/ios/ipa/`

> **Note:** Requires macOS with Xcode. Configure signing in Xcode before building.

### With Sentry Error Tracking

```bash
SENTRY_DSN=https://your-dsn@sentry.io/123 ./scripts/build_prod_apk.sh
```

---

## 4. Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                  # Primary entry point
│   ├── main_dev.dart              # Dev convenience entry
│   ├── main_prod.dart             # Prod convenience entry
│   ├── core/
│   │   ├── config/
│   │   │   └── env_config.dart    # Environment configuration
│   │   ├── api/
│   │   │   ├── api_config.dart    # API endpoints + env-aware base URL
│   │   │   ├── api_client.dart    # Dio HTTP client + env-aware logging
│   │   │   └── auth_interceptor.dart
│   │   ├── auth/                  # JWT storage, auth state
│   │   ├── theme/                 # Colors, spacing, typography
│   │   ├── widgets/               # Shared UI components
│   │   └── utils/                 # Formatters
│   ├── features/
│   │   ├── auth/                  # Login, OTP, Signup
│   │   ├── dashboard/             # Dashboard + KPIs
│   │   ├── invoices/              # CRUD + payments
│   │   ├── customers/             # Customer management
│   │   ├── credit_notes/          # Credit note CRUD
│   │   ├── payments/              # Payment recording
│   │   ├── reports/               # Financial reports
│   │   ├── gst/                   # GST dashboard
│   │   ├── ai_chat/               # AI assistant
│   │   └── settings/              # App settings
│   └── routing/
│       ├── app_router.dart        # GoRouter routes
│       └── shell_screen.dart      # Responsive navigation shell
├── scripts/
│   ├── run_dev.sh                 # Dev run script
│   ├── run_staging.sh             # Staging run script
│   ├── build_prod_apk.sh          # Prod APK build
│   ├── build_prod_appbundle.sh    # Prod AAB build (Play Store)
│   └── build_prod_ios.sh          # Prod iOS build
├── .vscode/
│   └── launch.json                # VS Code launch configs
└── pubspec.yaml
```

---

## 5. Common Issues

### "Connection refused" on Android emulator
The emulator can't reach `localhost`. It uses `10.0.2.2` to connect to the host machine.
This is already the default in DEV mode. Just make sure the Spring Boot backend is running.

### "Connection refused" on physical device
Use your machine's LAN IP (find with `ifconfig` or `ip addr`):
```bash
API_URL=http://192.168.1.100:8080 ./scripts/run_dev.sh
```
Also ensure your phone and machine are on the same WiFi network.

### iOS localhost connection
On iOS simulator, `localhost` works directly. For physical iOS devices, use your LAN IP.

### Backend CORS issues
If you get CORS errors in web mode, ensure the Spring Boot backend allows `http://localhost:*`
in its CORS configuration.
