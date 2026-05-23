import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

const _adminTokenKey = 'platform_admin_jwt';

final platformAdminRepositoryProvider =
    Provider<PlatformAdminRepository>((ref) {
  return PlatformAdminRepository(ref.watch(apiClientProvider));
});

class PlatformAdminRepository {
  final ApiClient _apiClient;

  /// Separate Dio instance for platform admin v2 API calls.
  /// Uses the platform admin JWT stored under [_adminTokenKey].
  late final Dio _adminDio;

  PlatformAdminRepository(this._apiClient) {
    _adminDio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _adminDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readAdminToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // ── Token helpers ──

  static final FlutterSecureStorage? _secureStorage = kIsWeb
      ? null
      : const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static Future<String?> _readAdminToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_adminTokenKey);
    }
    return _secureStorage!.read(key: _adminTokenKey);
  }

  // ── Legacy v1 methods (existing — use regular ApiClient) ──

  Future<List<Map<String, dynamic>>> organisations({String? status}) async {
    final response = await _apiClient.get(
      ApiConfig.platformOrganisations,
      queryParameters: {
        if (status != null) 'status': status,
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  Future<List<Map<String, dynamic>>> users(String orgId) async {
    final response = await _apiClient.get(ApiConfig.platformOrgUsers(orgId));
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  Future<void> approveOrg(String orgId, {String? note}) async {
    await _apiClient.post(
      ApiConfig.platformApproveOrg(orgId),
      data: {'note': note},
    );
  }

  Future<void> rejectOrg(String orgId, {String? note}) async {
    await _apiClient.post(
      ApiConfig.platformRejectOrg(orgId),
      data: {'note': note},
    );
  }

  Future<void> resetPassword(String userId, String newPassword,
      {String? reason}) async {
    await _apiClient.post(
      ApiConfig.platformResetPassword(userId),
      data: {
        'newPassword': newPassword,
        if (reason != null) 'reason': reason,
      },
    );
  }

  // ── V2 methods (platform admin API — use _adminDio) ──

  /// Login as platform admin. Returns { accessToken, adminId, fullName, role }.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _adminDio.post(
      ApiConfig.platformAdminLogin,
      data: {'email': email, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get dashboard stats.
  Future<Map<String, dynamic>> stats() async {
    final response = await _adminDio.get(ApiConfig.platformAdminStats);
    return response.data as Map<String, dynamic>;
  }

  /// List all orgs (v2 API).
  Future<List<Map<String, dynamic>>> organisationsV2({
    String? status,
    String? search,
    int? page,
    int? size,
  }) async {
    final response = await _adminDio.get(
      ApiConfig.platformAdminOrgsV2,
      queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (page != null) 'page': page,
        if (size != null) 'size': size,
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  /// Approve org (v2).
  Future<void> approveOrgV2(String orgId, {String? note}) async {
    await _adminDio.post(
      ApiConfig.platformAdminApproveOrgV2(orgId),
      data: {if (note != null) 'note': note},
    );
  }

  /// Reject org (v2).
  Future<void> rejectOrgV2(String orgId, {String? reason}) async {
    await _adminDio.post(
      ApiConfig.platformAdminRejectOrgV2(orgId),
      data: {if (reason != null) 'reason': reason},
    );
  }

  /// Suspend org.
  Future<void> suspendOrg(String orgId, String reason) async {
    await _adminDio.post(
      ApiConfig.platformAdminSuspendOrg(orgId),
      data: {'reason': reason},
    );
  }

  /// Reactivate org.
  Future<void> reactivateOrg(String orgId) async {
    await _adminDio.post(ApiConfig.platformAdminReactivateOrg(orgId));
  }

  /// List all users (v2 API).
  Future<List<Map<String, dynamic>>> usersV2({
    String? search,
    int? page,
    int? size,
  }) async {
    final response = await _adminDio.get(
      ApiConfig.platformAdminUsersV2,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (page != null) 'page': page,
        if (size != null) 'size': size,
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  /// Reset user password (v2).
  Future<void> resetPasswordV2(String userId, String newPassword,
      {String? reason, bool notifyUser = false}) async {
    await _adminDio.post(
      ApiConfig.platformAdminResetUserPasswordV2(userId),
      data: {
        'newPassword': newPassword,
        if (reason != null) 'reason': reason,
        'notifyUser': notifyUser,
      },
    );
  }

  /// Deactivate user.
  Future<void> deactivateUser(String userId, String reason) async {
    await _adminDio.post(
      ApiConfig.platformAdminDeactivateUser(userId),
      data: {'reason': reason},
    );
  }

  /// Reactivate user.
  Future<void> reactivateUser(String userId) async {
    await _adminDio.post(ApiConfig.platformAdminReactivateUser(userId));
  }

  /// Get audit log (paginated).
  Future<Map<String, dynamic>> auditLog({int page = 0, int size = 20}) async {
    final response = await _adminDio.get(
      ApiConfig.platformAdminAuditLog,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data as Map<String, dynamic>;
  }
}
