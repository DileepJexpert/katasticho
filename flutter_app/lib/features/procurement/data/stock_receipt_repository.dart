import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final stockReceiptRepositoryProvider =
    Provider<StockReceiptRepository>((ref) {
  return StockReceiptRepository(ref.watch(apiClientProvider));
});

class StockReceiptRepository {
  final ApiClient _api;

  StockReceiptRepository(this._api);

  Future<Map<String, dynamic>> listReceipts({
    int page = 0,
    int size = 20,
    String? supplierId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
    };
    debugPrint('[StockReceiptRepo] list params=$params');
    try {
      final response =
          await _api.get(ApiConfig.stockReceipts, queryParameters: params);
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[StockReceiptRepo] list FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    final response = await _api.get(ApiConfig.stockReceiptById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createReceipt(Map<String, dynamic> data) async {
    debugPrint('[StockReceiptRepo] create data=$data');
    final response = await _api.post(ApiConfig.stockReceipts, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Posts the GRN — flips DRAFT → RECEIVED and writes one PURCHASE
  /// movement per line in the inventory ledger. The backend rejects this
  /// if the receipt is not in DRAFT state.
  Future<Map<String, dynamic>> receiveReceipt(String id) async {
    final response = await _api.post(ApiConfig.receiveStockReceipt(id));
    return response.data as Map<String, dynamic>;
  }

  /// Cancels a receipt. If it was already RECEIVED the backend reverses
  /// every stock movement (does not touch the immutable ledger — it writes
  /// negative reversal rows instead).
  Future<Map<String, dynamic>> cancelReceipt(String id, String reason) async {
    final response = await _api.post(
      ApiConfig.cancelStockReceipt(id),
      data: {'reason': reason},
    );
    return response.data as Map<String, dynamic>;
  }
}

/// Page of receipts, optionally filtered by supplier.
final stockReceiptListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, supplierId) async {
  final repo = ref.watch(stockReceiptRepositoryProvider);
  return repo.listReceipts(supplierId: supplierId);
});

final stockReceiptDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(stockReceiptRepositoryProvider);
  return repo.getReceipt(id);
});
