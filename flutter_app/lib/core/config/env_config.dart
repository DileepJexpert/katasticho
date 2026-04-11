import 'package:flutter/foundation.dart' show kIsWeb;

/// App environment types.
enum AppEnvironment { dev, staging, prod }

/// Centralized environment configuration.
/// Values are injected at build time via --dart-define flags.
///
/// Local dev:
///   flutter run --dart-define=ENV=dev
///
/// Staging:
///   flutter run --dart-define=ENV=staging
///
/// Production:
///   flutter run --release --dart-define=ENV=prod
///
class EnvConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Current environment.
  static AppEnvironment get environment => switch (_env) {
        'prod' || 'production' => AppEnvironment.prod,
        'staging' => AppEnvironment.staging,
        _ => AppEnvironment.dev,
      };

  static bool get isDev => environment == AppEnvironment.dev;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProd => environment == AppEnvironment.prod;

  /// API base URL.
  /// Priority: --dart-define override > environment default.
  /// Web uses localhost, Android emulator uses 10.0.2.2 (host alias).
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return switch (environment) {
      AppEnvironment.dev => kIsWeb
          ? 'http://localhost:8080'
          : 'http://10.0.2.2:8080',
      AppEnvironment.staging => 'https://staging-api.katasticho.com',
      AppEnvironment.prod => 'https://api.katasticho.com',
    };
  }

  /// Connection timeout per environment.
  static Duration get connectTimeout => switch (environment) {
        AppEnvironment.dev => const Duration(seconds: 30),
        _ => const Duration(seconds: 15),
      };

  /// Receive timeout per environment.
  static Duration get receiveTimeout => switch (environment) {
        AppEnvironment.dev => const Duration(seconds: 60),
        _ => const Duration(seconds: 30),
      };

  /// Whether to show debug banner.
  static bool get showDebugBanner => isDev;

  /// Whether to enable detailed logging.
  static bool get enableLogging => !isProd;

  /// Whether to enable performance monitoring.
  static bool get enablePerformanceMonitoring => isProd || isStaging;

  /// Sentry DSN (only for staging/prod).
  static String get sentryDsn => _sentryDsn;

  /// App display name per environment.
  static String get appName => switch (environment) {
        AppEnvironment.dev => 'Katasticho DEV',
        AppEnvironment.staging => 'Katasticho STG',
        AppEnvironment.prod => 'Katasticho ERP',
      };

  /// Summary for logging at startup.
  static Map<String, String> get summary => {
        'environment': _env,
        'apiBaseUrl': apiBaseUrl,
        'logging': enableLogging.toString(),
        'perfMonitoring': enablePerformanceMonitoring.toString(),
      };
}
