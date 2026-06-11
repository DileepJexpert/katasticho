import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final integrationRepositoryProvider = Provider<IntegrationRepository>((ref) {
  return IntegrationRepository(ref.watch(apiClientProvider));
});

class IntegrationRepository {
  final ApiClient _api;
  IntegrationRepository(this._api);

  Future<List<dynamic>> listIntegrations() async {
    try {
      final res = await _api.get(ApiConfig.integrations);
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getIntegration(String id) async {
    final res = await _api.get(ApiConfig.integrationById(id));
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

  Future<Map<String, dynamic>> syncIntegration(String id) async {
    final res = await _api.post(ApiConfig.integrationSync(id));
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

  Future<void> toggleIntegration(String id, bool enabled) async {
    await _api.post(
      enabled
          ? ApiConfig.integrationEnable(id)
          : ApiConfig.integrationDisable(id),
    );
  }
}
