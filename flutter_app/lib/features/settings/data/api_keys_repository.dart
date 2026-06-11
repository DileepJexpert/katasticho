import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final apiKeysRepositoryProvider = Provider<ApiKeysRepository>((ref) {
  return ApiKeysRepository(ref.watch(apiClientProvider));
});

class ApiKey {
  final String id;
  final String name;
  final String keyPrefix;
  final bool active;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  ApiKey({
    required this.id,
    required this.name,
    required this.keyPrefix,
    required this.active,
    this.lastUsedAt,
    this.expiresAt,
    this.revokedAt,
    this.createdAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> j) => ApiKey(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        keyPrefix: j['keyPrefix']?.toString() ?? '',
        active: j['active'] as bool? ?? false,
        lastUsedAt: _dt(j['lastUsedAt']),
        expiresAt: _dt(j['expiresAt']),
        revokedAt: _dt(j['revokedAt']),
        createdAt: _dt(j['createdAt']),
      );

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

class ApiKeysRepository {
  final ApiClient _api;

  ApiKeysRepository(this._api);

  Future<List<ApiKey>> list() async {
    final resp = await _api.get(ApiConfig.apiKeys);
    final data = (resp.data as Map<String, dynamic>)['data'] as List? ?? const [];
    return data
        .map((e) => ApiKey.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates a key and returns the **plaintext** secret (shown only once).
  Future<String> create(String name, {int? expiresInDays}) async {
    final resp = await _api.post(ApiConfig.apiKeys, data: {
      'name': name,
      if (expiresInDays != null && expiresInDays > 0) 'expiresInDays': expiresInDays,
    });
    final data =
        (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ??
            const {};
    return data['key']?.toString() ?? '';
  }

  Future<void> revoke(String id) async {
    await _api.delete(ApiConfig.apiKeyById(id));
  }
}
