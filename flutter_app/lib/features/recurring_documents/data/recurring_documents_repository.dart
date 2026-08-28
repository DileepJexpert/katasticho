import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final recurringDocumentsRepositoryProvider =
    Provider<RecurringDocumentsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return RecurringDocumentsRepository(api);
});

final recurringBillsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(recurringDocumentsRepositoryProvider);
  return repo.listRecurringBills();
});

final recurringJournalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(recurringDocumentsRepositoryProvider);
  return repo.listRecurringJournals();
});

class RecurringDocumentsRepository {
  final ApiClient _api;
  RecurringDocumentsRepository(this._api);

  // ── Recurring Bills ──
  Future<List<Map<String, dynamic>>> listRecurringBills({String? status, int page = 0, int size = 50}) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
    };
    final res = await _api.get(ApiConfig.recurringBills, queryParameters: params);
    final data = res.data['data'] ?? res.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : (data is List ? data : []);
    return content.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createRecurringBill(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.recurringBills, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRecurringBill(String id, Map<String, dynamic> payload) async {
    final res = await _api.put(ApiConfig.recurringBillById(id), data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<void> stopRecurringBill(String id) async {
    await _api.post(ApiConfig.recurringBillStop(id));
  }

  Future<Map<String, dynamic>> generateRecurringBillNow(String id) async {
    final res = await _api.post(ApiConfig.recurringBillGenerate(id));
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  // ── Recurring Journals ──
  Future<List<Map<String, dynamic>>> listRecurringJournals({String? status, int page = 0, int size = 50}) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
    };
    final res = await _api.get(ApiConfig.recurringJournals, queryParameters: params);
    final data = res.data['data'] ?? res.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : (data is List ? data : []);
    return content.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createRecurringJournal(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.recurringJournals, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRecurringJournal(String id, Map<String, dynamic> payload) async {
    final res = await _api.put(ApiConfig.recurringJournalById(id), data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<void> stopRecurringJournal(String id) async {
    await _api.post(ApiConfig.recurringJournalStop(id));
  }

  Future<Map<String, dynamic>> generateRecurringJournalNow(String id) async {
    final res = await _api.post(ApiConfig.recurringJournalGenerate(id));
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }
}
