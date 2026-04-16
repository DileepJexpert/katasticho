import 'package:dio/dio.dart';

/// Extracts a user-friendly error message from a Dio error response.
///
/// The backend returns errors in the format:
/// ```json
/// { "success": false, "message": "Validation failed", "errors": ["sku: SKU is required", ...] }
/// ```
///
/// This utility parses that structure and returns either field-level
/// errors (for inline display) or a single message for snackbar display.
class ApiErrorParser {
  /// Parse the error response into a map of field name → error message.
  /// Returns an empty map if the response isn't a validation error.
  static Map<String, String> fieldErrors(DioException error) {
    final data = error.response?.data;
    if (data is! Map<String, dynamic>) return {};

    final errors = data['errors'];
    if (errors is! List || errors.isEmpty) return {};

    final result = <String, String>{};
    for (final e in errors) {
      final str = e.toString();
      final colonIdx = str.indexOf(':');
      if (colonIdx > 0) {
        final field = str.substring(0, colonIdx).trim();
        final message = str.substring(colonIdx + 1).trim();
        result[field] = message;
      }
    }
    return result;
  }

  /// Extract a single user-friendly message from the error.
  /// Prefers the backend `message` field, falls back to status text.
  static String message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          final errors = data['errors'];
          if (errors is List && errors.isNotEmpty) {
            return errors.map((e) {
              final str = e.toString();
              final colonIdx = str.indexOf(':');
              if (colonIdx > 0) return str.substring(colonIdx + 1).trim();
              return str;
            }).join(', ');
          }
          return msg;
        }
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }
}
