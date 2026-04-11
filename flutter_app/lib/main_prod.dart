/// Production entry point.
/// Build with: flutter build apk -t lib/main_prod.dart --dart-define=ENV=prod
///
/// For iOS:
///   flutter build ios -t lib/main_prod.dart --dart-define=ENV=prod
///
/// With Sentry DSN:
///   flutter build apk -t lib/main_prod.dart \
///     --dart-define=ENV=prod \
///     --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/123
library;

export 'main.dart';
