import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';

class OrganisationRepository {
  final ApiClient _client;
  OrganisationRepository(this._client);

  Future<void> updateIndustry({
    required String orgId,
    required String businessType,
    required String industryCode,
    required List<String> subCategories,
    String? gstin,
    String? state,
    String? stateCode,
    String? phone,
  }) async {
    await _client.put('/api/v1/organisations/$orgId/industry', data: {
      'businessType': businessType,
      'industryCode': industryCode,
      'subCategories': subCategories,
      if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
      if (state != null && state.isNotEmpty) 'state': state,
      if (stateCode != null && stateCode.isNotEmpty) 'stateCode': stateCode,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<void> completeOnboarding(String orgId) async {
    await _client.post('/api/v1/organisations/$orgId/onboarding-complete');
  }

  Future<Map<String, dynamic>> getOrg(String orgId) async {
    final res = await _client.get('/api/v1/organisations/$orgId');
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }
}

final organisationRepositoryProvider = Provider<OrganisationRepository>((ref) {
  return OrganisationRepository(ref.watch(apiClientProvider));
});

final orgDetailsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final orgId = ref.watch(authProvider).orgId;
  if (orgId == null || orgId.isEmpty) return {};
  return ref.watch(organisationRepositoryProvider).getOrg(orgId);
});
