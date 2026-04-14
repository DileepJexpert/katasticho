import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});

/// Filter bundle for the list provider.
class ExpenseFilters {
  final DateTime? from;
  final DateTime? to;
  final String? category;
  final String? contactId;

  const ExpenseFilters({this.from, this.to, this.category, this.contactId});

  @override
  bool operator ==(Object other) =>
      other is ExpenseFilters &&
      other.from == from &&
      other.to == to &&
      other.category == category &&
      other.contactId == contactId;

  @override
  int get hashCode => Object.hash(from, to, category, contactId);
}

class ExpenseRepository {
  final ApiClient _api;

  ExpenseRepository(this._api);

  Future<Map<String, dynamic>> listExpenses({
    int page = 0,
    int size = 20,
    DateTime? from,
    DateTime? to,
    String? category,
    String? contactId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (from != null) 'from': _formatDate(from),
      if (to != null) 'to': _formatDate(to),
      if (category != null && category.isNotEmpty) 'category': category,
      if (contactId != null) 'contactId': contactId,
    };
    debugPrint('[ExpenseRepo] listExpenses params: $params');
    final response = await _api.get(ApiConfig.expenses, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExpense(String id) async {
    debugPrint('[ExpenseRepo] getExpense id: $id');
    final response = await _api.get(ApiConfig.expenseById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    debugPrint('[ExpenseRepo] createExpense: $data');
    final response = await _api.post(ApiConfig.expenses, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateExpense(
      String id, Map<String, dynamic> data) async {
    debugPrint('[ExpenseRepo] updateExpense id: $id');
    final response = await _api.put(ApiConfig.expenseById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> voidExpense(String id, {String? reason}) async {
    debugPrint('[ExpenseRepo] voidExpense id: $id');
    await _api.delete(
      ApiConfig.expenseById(id),
      data: {'reason': reason ?? 'Voided'},
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Providers ──

final expenseListProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, ExpenseFilters>(
  (ref, filters) async {
    final repo = ref.watch(expenseRepositoryProvider);
    return repo.listExpenses(
      from: filters.from,
      to: filters.to,
      category: filters.category,
      contactId: filters.contactId,
    );
  },
);

final expenseDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(expenseRepositoryProvider);
    return repo.getExpense(id);
  },
);
