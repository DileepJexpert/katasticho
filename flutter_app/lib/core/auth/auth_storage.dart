import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage();
});

/// Secure storage for JWT tokens, org info, and user preferences.
///
/// Uses [FlutterSecureStorage] on mobile (encrypted) and
/// [SharedPreferences] on web (localStorage — avoids Web Crypto OperationError).
class AuthStorage {
  static const _prefix = 'katasticho_';
  static const _accessTokenKey = '${_prefix}access_token';
  static const _refreshTokenKey = '${_prefix}refresh_token';
  static const _orgIdKey = '${_prefix}org_id';
  static const _orgNameKey = '${_prefix}org_name';
  static const _userIdKey = '${_prefix}user_id';
  static const _userNameKey = '${_prefix}user_name';
  static const _userRoleKey = '${_prefix}user_role';
  static const _industryKey = '${_prefix}industry';

  // Mobile: encrypted secure storage
  final FlutterSecureStorage? _secureStorage = kIsWeb
      ? null
      : const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  // ── Low-level read/write ──

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage!.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secureStorage!.read(key: key);
  }

  Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } else {
      await _secureStorage!.deleteAll();
    }
  }

  // ── Token Operations ──

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('[AuthStorage] saveTokens called (web: $kIsWeb)');
    await Future.wait([
      _write(_accessTokenKey, accessToken),
      _write(_refreshTokenKey, refreshToken),
    ]);
    debugPrint('[AuthStorage] Tokens saved successfully');
  }

  Future<String?> getAccessToken() async {
    final token = await _read(_accessTokenKey);
    debugPrint('[AuthStorage] getAccessToken: ${token != null ? "present (${token.length} chars)" : "null"}');
    return token;
  }

  Future<String?> getRefreshToken() async {
    final token = await _read(_refreshTokenKey);
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
      _write(_userIdKey, userId),
      _write(_userNameKey, userName),
      _write(_userRoleKey, role),
    ]);
    debugPrint('[AuthStorage] User info saved successfully');
  }

  Future<String?> getUserId() async {
    final v = await _read(_userIdKey);
    debugPrint('[AuthStorage] getUserId: $v');
    return v;
  }

  Future<String?> getUserName() async {
    final v = await _read(_userNameKey);
    debugPrint('[AuthStorage] getUserName: $v');
    return v;
  }

  Future<String?> getUserRole() async {
    final v = await _read(_userRoleKey);
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
      _write(_orgIdKey, orgId),
      _write(_orgNameKey, orgName),
      if (industry != null) _write(_industryKey, industry),
    ]);
    debugPrint('[AuthStorage] Org info saved successfully');
  }

  Future<String?> getOrgId() async {
    final v = await _read(_orgIdKey);
    debugPrint('[AuthStorage] getOrgId: $v');
    return v;
  }

  Future<String?> getOrgName() async {
    final v = await _read(_orgNameKey);
    debugPrint('[AuthStorage] getOrgName: $v');
    return v;
  }

  Future<String?> getIndustry() async {
    final v = await _read(_industryKey);
    debugPrint('[AuthStorage] getIndustry: $v');
    return v;
  }

  // ── Clear ──

  Future<void> clearAll() async {
    debugPrint('[AuthStorage] clearAll called');
    await _deleteAll();
    debugPrint('[AuthStorage] All storage cleared');
  }

  Future<bool> hasValidSession() async {
    final token = await _read(_accessTokenKey);
    final valid = token != null && token.isNotEmpty;
    debugPrint('[AuthStorage] hasValidSession: $valid');
    return valid;
  }
}
