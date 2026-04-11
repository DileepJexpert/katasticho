import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../auth/auth_storage.dart';
import '../config/env_config.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final authStorage = ref.watch(authStorageProvider);
  return ApiClient(authStorage: authStorage);
});

class ApiClient {
  late final Dio dio;
  final AuthStorage authStorage;
  final _logger = Logger(
    level: EnvConfig.enableLogging ? Level.debug : Level.warning,
  );

  ApiClient({required this.authStorage}) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(
      AuthInterceptor(dio: dio, authStorage: authStorage),
    );

    // Only add verbose logging in non-production environments
    if (EnvConfig.enableLogging) {
      dio.interceptors.add(_loggingInterceptor());
    }
  }

  InterceptorsWrapper _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.d('→ ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('← ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.e(
          '✗ ${error.response?.statusCode} ${error.requestOptions.uri}',
          error: error.message,
        );
        handler.next(error);
      },
    );
  }

  // ── Convenience Methods ──

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.put<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) {
    return dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return dio.delete<T>(path);
  }
}
