import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';

class FeatureFlagRepository {
  final ApiClient _client;
  FeatureFlagRepository(this._client);

  Future<Set<String>> getEnabledFeatures() async {
    final resp = await _client.get('/api/v1/settings/features');
    final list = (resp.data['data'] as List?) ?? [];
    return list
        .where((f) => f['enabled'] == true)
        .map<String>((f) => f['feature'].toString())
        .toSet();
  }

  Future<void> toggleFeature(String feature, {required bool enabled}) async {
    await _client.put('/api/v1/settings/features/$feature',
        data: {'enabled': enabled});
  }

  Future<void> resetToDefaults() async {
    await _client.post('/api/v1/settings/features/reset');
  }
}

final featureFlagRepositoryProvider = Provider<FeatureFlagRepository>((ref) {
  return FeatureFlagRepository(ref.watch(apiClientProvider));
});

final featureFlagsProvider = FutureProvider<Set<String>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return {};
  return ref.read(featureFlagRepositoryProvider).getEnabledFeatures();
});
