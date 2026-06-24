import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final integrationRepositoryProvider = Provider<IntegrationRepository>((ref) {
  return IntegrationRepository(ref.watch(apiClientProvider));
});

/// Wraps `/api/v1/integrations`. Field names + endpoints mirror the backend
/// `IntegrationConfig` entity exactly (integrationType / isActive / lastSyncAt);
/// there are no `/enable|/disable` endpoints — active state is toggled via
/// `PUT /{id}` with `{isActive}`, and sync needs `syncType` + `direction`.
class IntegrationRepository {
  final ApiClient _api;
  IntegrationRepository(this._api);

  /// Errors propagate so the UI can show them (a 4xx/5xx must NOT render as an
  /// empty "nothing configured" state).
  Future<List<dynamic>> listIntegrations() async {
    final res = await _api.get(ApiConfig.integrations);
    final data = res.data['data'];
    if (data is List) return data;
    if (data is Map) {
      final content = data['content'];
      if (content is List) return content;
    }
    return [];
  }

  Future<Map<String, dynamic>> getIntegration(String id) async {
    final res = await _api.get(ApiConfig.integrationById(id));
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> createIntegration({
    required String integrationType,
    required String name,
    String? baseUrl,
    String? apiKey,
    Map<String, dynamic>? settings,
  }) async {
    final res = await _api.post(ApiConfig.integrations, data: {
      'integrationType': integrationType,
      'name': name,
      if (baseUrl != null && baseUrl.isNotEmpty) 'baseUrl': baseUrl,
      if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
      if (settings != null) 'settings': settings,
    });
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> testConnection(String id) async {
    final res = await _api.post(ApiConfig.integrationTestConnection(id));
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// Backend: `POST /{id}/sync?syncType=&direction=` (both required params).
  Future<Map<String, dynamic>> syncIntegration(
    String id, {
    String syncType = 'GENERAL',
    String direction = 'EXPORT',
  }) async {
    final res = await _api.post(
      '${ApiConfig.integrationSync(id)}?syncType=$syncType&direction=$direction',
    );
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> updateIntegrationConfig(
      String id, Map<String, dynamic> config) async {
    final res = await _api.put(ApiConfig.integrationById(id), data: config);
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// No `/enable|/disable` on the backend — toggle active via `PUT /{id}`.
  Future<void> toggleIntegration(String id, bool active) async {
    await _api.put(ApiConfig.integrationById(id), data: {'isActive': active});
  }
}
