import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final bankReconciliationRepositoryProvider =
    Provider<BankReconciliationRepository>((ref) {
  return BankReconciliationRepository(ref.watch(apiClientProvider));
});

class BankReconciliationRepository {
  final ApiClient _api;

  BankReconciliationRepository(this._api);

  Future<Map<String, dynamic>> listTransactions({
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _api.get(
      ApiConfig.bankingTransactions,
      queryParameters: {
        'page': page,
        'size': size,
        if (status != null && status.isNotEmpty && status != 'ALL')
          'status': status,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importCsv(String csvText) async {
    final response = await _api.post(
      ApiConfig.bankingImportCsv,
      data: {'csvText': csvText},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rerunMatch(String transactionId) async {
    final response =
        await _api.post(ApiConfig.bankingRerunMatch(transactionId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ignoreTransaction(String transactionId) async {
    final response =
        await _api.post(ApiConfig.bankingIgnoreTransaction(transactionId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptMatch(String matchId) async {
    final response = await _api.post(ApiConfig.bankingAcceptMatch(matchId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectMatch(String matchId) async {
    final response = await _api.post(ApiConfig.bankingRejectMatch(matchId));
    return response.data as Map<String, dynamic>;
  }
}
