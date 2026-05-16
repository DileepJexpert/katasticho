import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(apiClientProvider));
});

class TeamRepository {
  final ApiClient _api;
  TeamRepository(this._api);

  Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await _api.get(ApiConfig.orgUsers);
    final data = (res.data as Map<String, dynamic>)['data'];
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> listPendingInvites() async {
    final res = await _api.get(ApiConfig.orgPendingInvites);
    final data = (res.data as Map<String, dynamic>)['data'];
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> invite({
    required String role,
    String? email,
    String? phone,
  }) async {
    final res = await _api.post(ApiConfig.orgInvite, data: {
      'role': role,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<void> updateRole(String userId, String role) async {
    await _api.put(ApiConfig.orgUserRole(userId), data: {'role': role});
  }

  Future<void> deactivateUser(String userId) async {
    await _api.put(ApiConfig.orgUserDeactivate(userId));
  }

  Future<void> reactivateUser(String userId) async {
    await _api.put(ApiConfig.orgUserReactivate(userId));
  }

  Future<void> resendInvite(String inviteId) async {
    await _api.post(ApiConfig.orgInviteResend(inviteId));
  }

  Future<void> cancelInvite(String inviteId) async {
    await _api.delete(ApiConfig.orgInviteCancel(inviteId));
  }
}
