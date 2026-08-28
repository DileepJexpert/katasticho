import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'payout_models.dart';

class PayoutRepository {
  final ApiClient _client;
  PayoutRepository(this._client);

  Future<List<PayoutDisbursementModel>> listPayouts({int page = 0, int size = 50}) async {
    debugPrint('[PayoutRepo] listPayouts page=$page size=$size');
    try {
      final res = await _client.get(
        '/api/v1/payouts',
        queryParameters: {'page': page, 'size': size},
      );
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is Map && data['content'] is List) {
        final list = data['content'] as List;
        return list.map((item) => PayoutDisbursementModel.fromJson(item as Map<String, dynamic>)).toList();
      } else if (data is List) {
        return data.map((item) => PayoutDisbursementModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return const [];
    } catch (e, st) {
      debugPrint('[PayoutRepo] listPayouts FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<PayoutDisbursementModel> disburse(PayoutDisbursementRequestPayload request) async {
    debugPrint('[PayoutRepo] disburse amount=${request.amount} to contact=${request.contactId}');
    try {
      final res = await _client.post(
        '/api/v1/payouts/disburse',
        data: request.toJson(),
      );
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return PayoutDisbursementModel.fromJson(data);
    } catch (e, st) {
      debugPrint('[PayoutRepo] disburse FAILED: $e\n$st');
      rethrow;
    }
  }
}

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  return PayoutRepository(ref.watch(apiClientProvider));
});

final payoutsProvider = FutureProvider.autoDispose<List<PayoutDisbursementModel>>((ref) {
  return ref.watch(payoutRepositoryProvider).listPayouts();
});
