import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage();
});

/// Secure storage for JWT tokens, org info, and user preferences.
class AuthStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _orgIdKey = 'org_id';
  static const _orgNameKey = 'org_name';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userRoleKey = 'user_role';
  static const _industryKey = 'industry';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token Operations ──

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('[AuthStorage] saveTokens called');
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
    debugPrint('[AuthStorage] Tokens saved successfully');
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    debugPrint('[AuthStorage] getAccessToken: ${token != null ? "present (${token.length} chars)" : "null"}');
    return token;
  }

  Future<String?> getRefreshToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    debugPrint('[AuthStorage] getRefreshToken: ${token != null ? "present" : "null"}');
    return token;
  }

  // ── User Info ──

  Future<void> saveUserInfo({
    required String userId,
    required String userName,
    required String role,
  }) async {
    debugPrint('[AuthStorage] saveUserInfo -> userId: $userId, userName: $userName, role: $role');
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userNameKey, value: userName),
      _storage.write(key: _userRoleKey, value: role),
    ]);
    debugPrint('[AuthStorage] User info saved successfully');
  }

  Future<String?> getUserId() async {
    final v = await _storage.read(key: _userIdKey);
    debugPrint('[AuthStorage] getUserId: $v');
    return v;
  }

  Future<String?> getUserName() async {
    final v = await _storage.read(key: _userNameKey);
    debugPrint('[AuthStorage] getUserName: $v');
    return v;
  }

  Future<String?> getUserRole() async {
    final v = await _storage.read(key: _userRoleKey);
    debugPrint('[AuthStorage] getUserRole: $v');
    return v;
  }

  // ── Organisation ──

  Future<void> saveOrgInfo({
    required String orgId,
    required String orgName,
    String? industry,
  }) async {
    debugPrint('[AuthStorage] saveOrgInfo -> orgId: $orgId, orgName: $orgName, industry: $industry');
    await Future.wait([
      _storage.write(key: _orgIdKey, value: orgId),
      _storage.write(key: _orgNameKey, value: orgName),
      if (industry != null) _storage.write(key: _industryKey, value: industry),
    ]);
    debugPrint('[AuthStorage] Org info saved successfully');
  }

  Future<String?> getOrgId() async {
    final v = await _storage.read(key: _orgIdKey);
    debugPrint('[AuthStorage] getOrgId: $v');
    return v;
  }

  Future<String?> getOrgName() async {
    final v = await _storage.read(key: _orgNameKey);
    debugPrint('[AuthStorage] getOrgName: $v');
    return v;
  }

  Future<String?> getIndustry() async {
    final v = await _storage.read(key: _industryKey);
    debugPrint('[AuthStorage] getIndustry: $v');
    return v;
  }

  // ── Clear ──

  Future<void> clearAll() async {
    debugPrint('[AuthStorage] clearAll called');
    await _storage.deleteAll();
    debugPrint('[AuthStorage] All storage cleared');
  }

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _accessTokenKey);
    final valid = token != null && token.isNotEmpty;
    debugPrint('[AuthStorage] hasValidSession: $valid');
    return valid;
  }
}
