/// Dev entry point.
/// Run with: flutter run -t lib/main_dev.dart
///
/// This is equivalent to:
///   flutter run --dart-define=ENV=dev
///
/// For connecting to a local Spring Boot backend on a physical device,
/// override the API URL:
///   flutter run -t lib/main_dev.dart --dart-define=API_BASE_URL=http://192.168.1.x:8080
library;

export 'main.dart';
