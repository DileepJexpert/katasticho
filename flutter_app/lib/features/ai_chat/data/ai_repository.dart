import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});

class AiRepository {
  final ApiClient _api;

  AiRepository(this._api);

  /// Send a natural language query and get financial insights.
  Future<Map<String, dynamic>> query(String message) async {
    final response = await _api.post(
      ApiConfig.aiQuery,
      data: {'message': message},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Upload a bill image for scanning via Claude Vision.
  Future<Map<String, dynamic>> scanBill(String base64Image) async {
    final response = await _api.post(
      ApiConfig.aiScanBill,
      data: {'image': base64Image},
    );
    return response.data as Map<String, dynamic>;
  }
}
