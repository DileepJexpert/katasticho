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
    required int year,
    required int month,
  }) async {
    final response = await _api.get(ApiConfig.gstr1, queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGstr3b({
    required int year,
    required int month,
  }) async {
    final response = await _api.get(ApiConfig.gstr3b, queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }
}
