import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final fiscalPeriodRepositoryProvider =
    Provider<FiscalPeriodRepository>((ref) {
  return FiscalPeriodRepository(ref.watch(apiClientProvider));
});

final fiscalPeriodsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(fiscalPeriodRepositoryProvider);
  return repo.listPeriods();
});

class FiscalPeriodRepository {
  final ApiClient _api;

  FiscalPeriodRepository(this._api);

  Future<List<Map<String, dynamic>>> listPeriods() async {
    final response = await _api.get(ApiConfig.fiscalPeriods);
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> closePeriod(int year, int month) async {
    await _api.post(ApiConfig.closeFiscalPeriod(year, month));
  }

  Future<void> reopenPeriod(int year, int month) async {
    await _api.post(ApiConfig.reopenFiscalPeriod(year, month));
  }

  Future<void> lockPeriod(int year, int month) async {
    await _api.post(ApiConfig.lockFiscalPeriod(year, month));
  }
}
