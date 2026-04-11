import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_storage.dart';
import 'api_config.dart';

/// Attaches JWT access token to every request.
/// Handles 401 by attempting a token refresh, then retrying the original request.
class AuthInterceptor extends Interceptor {
  final Dio dio;
  final AuthStorage authStorage;
  bool _isRefreshing = false;

  AuthInterceptor({required this.dio, required this.authStorage});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    debugPrint('[AuthInterceptor] onRequest: ${options.method} ${options.path}');

    // Skip auth header for login/register/refresh endpoints
    final noAuthPaths = [
      ApiConfig.login,
      ApiConfig.requestOtp,
      ApiConfig.verifyOtp,
      ApiConfig.signup,
      ApiConfig.refreshToken,
    ];
    if (noAuthPaths.any((p) => options.path.contains(p))) {
      debugPrint('[AuthInterceptor] Skipping auth header for auth endpoint: ${options.path}');
      return handler.next(options);
    }

    final token = await authStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('[AuthInterceptor] Added Bearer token (${token.length} chars)');
    } else {
      debugPrint('[AuthInterceptor] No access token available');
    }

    // Add org header if available
    final orgId = await authStorage.getOrgId();
    if (orgId != null) {
      options.headers['X-Org-Id'] = orgId;
      debugPrint('[AuthInterceptor] Added X-Org-Id: $orgId');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    debugPrint('[AuthInterceptor] onError: ${err.response?.statusCode} ${err.requestOptions.path} - ${err.message}');

    if (err.response?.statusCode != 401 || _isRefreshing) {
      debugPrint('[AuthInterceptor] Not a 401 or already refreshing, passing error through');
      return handler.next(err);
    }

    // Skip refresh attempt for auth endpoints
    if (err.requestOptions.path.contains('/auth/')) {
      debugPrint('[AuthInterceptor] Auth endpoint 401, skipping refresh');
      return handler.next(err);
    }

    debugPrint('[AuthInterceptor] 401 detected, attempting token refresh...');
    _isRefreshing = true;
    try {
      final refreshToken = await authStorage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('[AuthInterceptor] No refresh token, clearing session');
        await authStorage.clearAll();
        return handler.next(err);
      }

      debugPrint('[AuthInterceptor] Sending refresh token request...');
      // Attempt token refresh
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await refreshDio.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['data']['accessToken'] as String;
        final newRefresh = response.data['data']['refreshToken'] as String;

        debugPrint('[AuthInterceptor] Token refresh successful, saving new tokens');
        await authStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccess';

        debugPrint('[AuthInterceptor] Retrying original request: ${retryOptions.path}');
        final retryResponse = await dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } else {
        debugPrint('[AuthInterceptor] Token refresh returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[AuthInterceptor] Token refresh FAILED: $e');
      await authStorage.clearAll();
    } finally {
      _isRefreshing = false;
    }

    handler.next(err);
  }
}
