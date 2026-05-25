import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class IndentRepository {
  final ApiClient _api;
  IndentRepository(this._api);

  Future<List<Map<String, dynamic>>> list({String? status, int page = 0, int size = 50}) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (status != null) params['status'] = status;
    final res = await _api.get(ApiConfig.indents, queryParameters: params);
    final data = res.data;
    if (data is Map && data['content'] is List) {
      return List<Map<String, dynamic>>.from(data['content']);
    }
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get(ApiConfig.indentById(id));
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.indents, data: body);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> markOrdered(String id, String purchaseOrderId) async {
    final res = await _api.put('${ApiConfig.indentById(id)}/mark-ordered?purchaseOrderId=$purchaseOrderId');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> markFulfilled(String id, String receiptId) async {
    final res = await _api.put('${ApiConfig.indentById(id)}/mark-fulfilled?receiptId=$receiptId');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> cancel(String id) async {
    await _api.put('${ApiConfig.indentById(id)}/cancel');
  }

  Future<Map<String, dynamic>> summary() async {
    final res = await _api.get(ApiConfig.indentSummary);
    return Map<String, dynamic>.from(res.data);
  }
}

final indentRepositoryProvider = Provider<IndentRepository>((ref) {
  return IndentRepository(ref.watch(apiClientProvider));
});

final indentListProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, status) {
  return ref.watch(indentRepositoryProvider).list(status: status);
});

final indentSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(indentRepositoryProvider).summary();
});
