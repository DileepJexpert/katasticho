import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final platformAdminRepositoryProvider = Provider<PlatformAdminRepository>((ref) {
  return PlatformAdminRepository(ref.watch(apiClientProvider));
});

class PlatformAdminRepository {
  final ApiClient _apiClient;

  PlatformAdminRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> organisations({String? status}) async {
    final response = await _apiClient.get(
      ApiConfig.platformOrganisations,
      queryParameters: {
        if (status != null) 'status': status,
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  Future<List<Map<String, dynamic>>> users(String orgId) async {
    final response = await _apiClient.get(ApiConfig.platformOrgUsers(orgId));
    final data = (response.data as Map<String, dynamic>)['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  Future<void> approveOrg(String orgId, {String? note}) async {
    await _apiClient.post(
      ApiConfig.platformApproveOrg(orgId),
      data: {'note': note},
    );
  }

  Future<void> rejectOrg(String orgId, {String? note}) async {
    await _apiClient.post(
      ApiConfig.platformRejectOrg(orgId),
      data: {'note': note},
    );
  }

  Future<void> resetPassword(String userId, String newPassword,
      {String? reason}) async {
    await _apiClient.post(
      ApiConfig.platformResetPassword(userId),
      data: {
        'newPassword': newPassword,
        if (reason != null) 'reason': reason,
      },
    );
  }
}
