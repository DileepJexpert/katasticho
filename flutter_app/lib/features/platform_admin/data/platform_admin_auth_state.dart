import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'platform_admin_jwt';

final platformAdminTokenProvider =
    StateNotifierProvider<PlatformAdminTokenNotifier, String?>((ref) {
  return PlatformAdminTokenNotifier();
});

/// Manages the platform admin JWT token in secure storage.
class PlatformAdminTokenNotifier extends StateNotifier<String?> {
  PlatformAdminTokenNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final token = await _read();
    state = token;
  }

  Future<void> setToken(String token) async {
    await _write(token);
    state = token;
  }

  Future<void> clearToken() async {
    await _delete();
    state = null;
  }

  // ── Storage helpers (same pattern as AuthStorage) ──

  static final FlutterSecureStorage? _secureStorage = kIsWeb
      ? null
      : const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static Future<void> _write(String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, value);
    } else {
      await _secureStorage!.write(key: _tokenKey, value: value);
    }
  }

  static Future<String?> _read() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return _secureStorage!.read(key: _tokenKey);
  }

  static Future<void> _delete() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } else {
      await _secureStorage!.delete(key: _tokenKey);
    }
  }
}
