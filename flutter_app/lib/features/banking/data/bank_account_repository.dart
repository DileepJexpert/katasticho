import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final bankAccountRepositoryProvider = Provider<BankAccountRepository>((ref) {
  return BankAccountRepository(ref.watch(apiClientProvider));
});

/// All bank accounts (default-first). [activeOnly] filters to live accounts —
/// used by pickers.
final bankAccountListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool>((ref, activeOnly) async {
  return ref.watch(bankAccountRepositoryProvider).list(activeOnly: activeOnly);
});

class BankAccountRepository {
  final ApiClient _api;

  BankAccountRepository(this._api);

  Future<List<Map<String, dynamic>>> list({bool activeOnly = false}) async {
    final res = await _api.get(ApiConfig.bankAccounts,
        queryParameters: {'active_only': activeOnly});
    final data = (res.data as Map<String, dynamic>)['data'] as List? ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.bankAccounts, data: body);
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiConfig.bankAccountById(id), data: body);
    return _unwrap(res.data);
  }

  Future<void> setDefault(String id) async {
    await _api.post(ApiConfig.bankAccountSetDefault(id));
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConfig.bankAccountById(id));
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    final map = data as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] ?? map) as Map);
  }
}
