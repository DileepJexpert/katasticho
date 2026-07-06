import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final bankRuleRepositoryProvider = Provider<BankRuleRepository>((ref) {
  return BankRuleRepository(ref.watch(apiClientProvider));
});

/// User-defined bank matching rules — categorise non-document bank transactions
/// (charges, interest, utilities, salaries) to a GL account.
/// Backend: `/api/v1/bank-rules` (BankRuleController).
class BankRuleRepository {
  final ApiClient _api;
  BankRuleRepository(this._api);

  Future<List<dynamic>> list() async {
    final res = await _api.get(ApiConfig.bankRules);
    final data = res.data['data'];
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.bankRules, data: body);
    final data = res.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiConfig.bankRuleById(id), data: body);
    final data = res.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConfig.bankRuleById(id));
  }
}
