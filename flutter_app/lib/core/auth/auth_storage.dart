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
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  // ── User Info ──

  Future<void> saveUserInfo({
    required String userId,
    required String userName,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userNameKey, value: userName),
      _storage.write(key: _userRoleKey, value: role),
    ]);
  }

  Future<String?> getUserId() => _storage.read(key: _userIdKey);
  Future<String?> getUserName() => _storage.read(key: _userNameKey);
  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  // ── Organisation ──

  Future<void> saveOrgInfo({
    required String orgId,
    required String orgName,
    String? industry,
  }) async {
    await Future.wait([
      _storage.write(key: _orgIdKey, value: orgId),
      _storage.write(key: _orgNameKey, value: orgName),
      if (industry != null) _storage.write(key: _industryKey, value: industry),
    ]);
  }

  Future<String?> getOrgId() => _storage.read(key: _orgIdKey);
  Future<String?> getOrgName() => _storage.read(key: _orgNameKey);
  Future<String?> getIndustry() => _storage.read(key: _industryKey);

  // ── Clear ──

  Future<void> clearAll() => _storage.deleteAll();

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
