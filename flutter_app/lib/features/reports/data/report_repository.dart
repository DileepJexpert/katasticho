import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(apiClientProvider));
});

class ReportRepository {
  final ApiClient _api;

  ReportRepository(this._api);

  Future<Map<String, dynamic>> getTrialBalance({String? asOfDate}) async {
    final params = <String, dynamic>{
      if (asOfDate != null) 'asOfDate': asOfDate,
    };
    final response =
        await _api.get(ApiConfig.trialBalance, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfitLoss({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _api.get(ApiConfig.profitLoss, queryParameters: {
      'startDate': startDate,
      'endDate': endDate,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBalanceSheet({String? asOfDate}) async {
    final params = <String, dynamic>{
      if (asOfDate != null) 'asOfDate': asOfDate,
    };
    final response =
        await _api.get(ApiConfig.balanceSheet, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGeneralLedger({
    required String accountId,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _api.get(
      ApiConfig.generalLedger(accountId),
      queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAgeingReport() async {
    final response = await _api.get(ApiConfig.ageingReport);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getApAgeingReport({String? asOfDate}) async {
    final params = <String, dynamic>{
      if (asOfDate != null) 'asOfDate': asOfDate,
    };
    final response =
        await _api.get(ApiConfig.apAgeingReport, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGstr1({
    required int year,
    required int month,
  }) async {
    final response = await _api.get(ApiConfig.gstr1, queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getContactLedger({
    required String contactId,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _api.get(
      ApiConfig.contactLedger(contactId),
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
