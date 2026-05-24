import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final purchaseOrderRepositoryProvider =
    Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepository(ref.watch(apiClientProvider));
});

class PurchaseOrderRepository {
  final ApiClient _api;

  PurchaseOrderRepository(this._api);

  Future<List<dynamic>> listPOs() async {
    debugPrint('[PurchaseOrderRepo] list');
    try {
      final response = await _api.get(ApiConfig.purchaseOrders);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) return inner;
      }
      return [];
    } catch (e, st) {
      debugPrint('[PurchaseOrderRepo] list FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _api.get(ApiConfig.purchaseOrderById(id));
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
    }
    return {};
  }

  Future<Map<String, dynamic>> createPO(Map<String, dynamic> body) async {
    debugPrint('[PurchaseOrderRepo] create body=$body');
    final response = await _api.post(ApiConfig.purchaseOrders, data: body);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePO(
      String id, Map<String, dynamic> body) async {
    debugPrint('[PurchaseOrderRepo] update id=$id body=$body');
    final response =
        await _api.put(ApiConfig.purchaseOrderById(id), data: body);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendPO(String id) async {
    final response = await _api.post(ApiConfig.sendPurchaseOrder(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelPO(String id) async {
    final response = await _api.post(ApiConfig.cancelPurchaseOrder(id));
    return response.data as Map<String, dynamic>;
  }
}

final purchaseOrdersProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return repo.listPOs();
});

final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(purchaseOrderRepositoryProvider);
  return repo.getById(id);
});
