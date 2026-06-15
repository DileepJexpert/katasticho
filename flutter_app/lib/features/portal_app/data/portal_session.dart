import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';

/// External portal session — a portal JWT held independently of the admin
/// app's auth. Lives in memory for the session (the external portal is a
/// lightweight, re-login-on-restart experience).
final portalTokenProvider = StateProvider<String?>((ref) => null);

/// The logged-in portal user's profile/dashboard summary (set after login).
final portalProfileProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// A Dio configured for the external portal: base URL + a Bearer portal token,
/// and deliberately NO admin auth header / X-Org-Id (the portal token carries
/// the org). Separate from the admin [ApiClient] so the two never cross over.
final portalDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(portalTokenProvider);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
  return dio;
});
