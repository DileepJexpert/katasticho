import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final cashRunwayRepositoryProvider = Provider<CashRunwayRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return CashRunwayRepository(api);
});

final cashRunwayQueryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(cashRunwayRepositoryProvider);
  return repo.get13WeekRunway();
});

class CashRunwayRepository {
  final ApiClient _api;
  CashRunwayRepository(this._api);

  Future<Map<String, dynamic>> get13WeekRunway({String? asOfDate}) async {
    final query = asOfDate != null ? '?asOfDate=$asOfDate' : '';
    final response = await _api.get('${ApiConfig.cashRunway13Week}$query');
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> simulateScenario({
    String? asOfDate,
    required Map<String, dynamic> simulation,
  }) async {
    final query = asOfDate != null ? '?asOfDate=$asOfDate' : '';
    final response = await _api.post(
      '${ApiConfig.cashRunwaySimulate}$query',
      data: simulation,
    );
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }
}