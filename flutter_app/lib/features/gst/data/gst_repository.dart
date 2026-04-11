import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final gstRepositoryProvider = Provider<GstRepository>((ref) {
  return GstRepository(ref.watch(apiClientProvider));
});

class GstRepository {
  final ApiClient _api;

  GstRepository(this._api);

  Future<Map<String, dynamic>> getGstr1({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _api.get(ApiConfig.gstr1, queryParameters: {
      'startDate': startDate,
      'endDate': endDate,
    });
    return response.data as Map<String, dynamic>;
  }
}
