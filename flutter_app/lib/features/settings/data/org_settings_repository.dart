import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final orgSettingsRepositoryProvider = Provider<OrgSettingsRepository>((ref) {
  return OrgSettingsRepository(ref.watch(apiClientProvider));
});

final orgSettingsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  return ref.watch(orgSettingsRepositoryProvider).getAll();
});

class OrgSettingsRepository {
  final ApiClient _api;

  OrgSettingsRepository(this._api);

  Future<Map<String, String>> getAll() async {
    final response = await _api.get(ApiConfig.orgSettings);
    final data = (response.data as Map<String, dynamic>);
    return data.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Future<Map<String, String>> updateAll(Map<String, String> settings) async {
    final response = await _api.put(ApiConfig.orgSettings, data: settings);
    final data = (response.data as Map<String, dynamic>);
    return data.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }
}
