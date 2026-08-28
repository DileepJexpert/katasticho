import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final paymentTermsRepositoryProvider = Provider<PaymentTermsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PaymentTermsRepository(api);
});

final paymentTermsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(paymentTermsRepositoryProvider);
  return repo.listPaymentTerms();
});

final dunningLevelsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(paymentTermsRepositoryProvider);
  return repo.listDunningLevels();
});

final dunningPreviewProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(paymentTermsRepositoryProvider);
  return repo.getDunningPreview();
});

class PaymentTermsRepository {
  final ApiClient _api;
  PaymentTermsRepository(this._api);

  // ── Payment Terms ──
  Future<List<Map<String, dynamic>>> listPaymentTerms({bool activeOnly = false}) async {
    final res = await _api.get('${ApiConfig.paymentTerms}?activeOnly=$activeOnly');
    final data = res.data['data'] ?? res.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getPaymentTerm(String id) async {
    final res = await _api.get(ApiConfig.paymentTermById(id));
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPaymentTerm(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.paymentTerms, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePaymentTerm(String id, Map<String, dynamic> payload) async {
    final res = await _api.put(ApiConfig.paymentTermById(id), data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<void> deletePaymentTerm(String id) async {
    await _api.delete(ApiConfig.paymentTermById(id));
  }

  // ── Dunning Levels & Automation ──
  Future<List<Map<String, dynamic>>> listDunningLevels() async {
    final res = await _api.get(ApiConfig.dunningLevels);
    final data = res.data['data'] ?? res.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createDunningLevel(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.dunningLevels, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDunningLevel(String id, Map<String, dynamic> payload) async {
    final res = await _api.put(ApiConfig.dunningLevelById(id), data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<void> deleteDunningLevel(String id) async {
    await _api.delete(ApiConfig.dunningLevelById(id));
  }

  Future<Map<String, dynamic>> runDunningSweep() async {
    final res = await _api.post(ApiConfig.dunningRun);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDunningPreview() async {
    final res = await _api.get(ApiConfig.dunningPreview);
    final data = res.data['data'] ?? res.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getDunningLogs({String? invoiceId, int page = 0, int size = 30}) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (invoiceId != null) 'invoiceId': invoiceId,
    };
    final res = await _api.get(ApiConfig.dunningLog, queryParameters: params);
    final data = res.data['data'] ?? res.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : (data is List ? data : []);
    return content.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
