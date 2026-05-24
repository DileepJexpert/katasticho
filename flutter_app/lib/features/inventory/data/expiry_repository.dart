import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final expiryRepositoryProvider = Provider<ExpiryRepository>((ref) {
  return ExpiryRepository(ref.watch(apiClientProvider));
});

class ExpiryRepository {
  final ApiClient _api;

  ExpiryRepository(this._api);

  Future<Map<String, dynamic>> getNearExpiryBatches({int days = 90}) async {
    debugPrint('[ExpiryRepo] getNearExpiryBatches days=$days');
    try {
      final response = await _api.get(ApiConfig.nearExpiryBatches(days: days));
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[ExpiryRepo] getNearExpiryBatches FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getExpirySummary() async {
    debugPrint('[ExpiryRepo] getExpirySummary');
    try {
      final response = await _api.get(ApiConfig.expirySummary);
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[ExpiryRepo] getExpirySummary FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> returnExpired({
    required List<Map<String, dynamic>> batches,
    required String reason,
  }) async {
    final lines = batches.map((b) => {
      'itemId': b['itemId'],
      'quantity': b['quantityOnHand'],
      if (b['batchId'] != null) 'batchId': b['batchId'],
    }).toList();

    await _api.post('/stock/expiry-return', data: {
      'returnDate': DateTime.now().toIso8601String().split('T').first,
      'reason': reason,
      'lines': lines,
    });
  }
}

/// Provider for expiry summary data.
final expirySummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(expiryRepositoryProvider);
  return repo.getExpirySummary();
});

/// Provider for near-expiry batches list, parameterized by days threshold.
final nearExpiryBatchesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, days) async {
  final repo = ref.watch(expiryRepositoryProvider);
  return repo.getNearExpiryBatches(days: days);
});
