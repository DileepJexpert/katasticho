import 'package:dio/dio.dart';
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
    // Skip auth header for login/register/refresh endpoints
    final noAuthPaths = [
      ApiConfig.login,
      ApiConfig.requestOtp,
      ApiConfig.verifyOtp,
      ApiConfig.signup,
      ApiConfig.refreshToken,
    ];
    if (noAuthPaths.any((p) => options.path.contains(p))) {
      return handler.next(options);
    }

    final token = await authStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Add org header if available
    final orgId = await authStorage.getOrgId();
    if (orgId != null) {
      options.headers['X-Org-Id'] = orgId;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    // Skip refresh attempt for auth endpoints
    if (err.requestOptions.path.contains('/auth/')) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await authStorage.getRefreshToken();
      if (refreshToken == null) {
        await authStorage.clearAll();
        return handler.next(err);
      }

      // Attempt token refresh
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await refreshDio.post(
        ApiConfig.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['data']['accessToken'] as String;
        final newRefresh = response.data['data']['refreshToken'] as String;

        await authStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccess';

        final retryResponse = await dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      }
    } catch (_) {
      await authStorage.clearAll();
    } finally {
      _isRefreshing = false;
    }

    handler.next(err);
  }
}
