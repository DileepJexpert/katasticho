import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  return CurrencyRepository(ref.watch(apiClientProvider));
});

class CurrencyRepository {
  final ApiClient _api;
  CurrencyRepository(this._api);

  Future<List<dynamic>> listCurrencies() async {
    try {
      final res = await _api.get(ApiConfig.currencies);
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getCurrency(String code) async {
    final res = await _api.get(ApiConfig.currencyByCode(code));
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<List<dynamic>> getExchangeRates({String? baseCurrency}) async {
    try {
      final url = baseCurrency != null
          ? '${ApiConfig.currencyRates}?base=$baseCurrency'
          : ApiConfig.currencyRates;
      final res = await _api.get(url);
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> setExchangeRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
  }) async {
    final res = await _api.post(ApiConfig.currencyRates, data: {
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'rate': rate,
    });
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final res = await _api.get(
      ApiConfig.currencyConvert,
      queryParameters: {
        'amount': amount,
        'from': fromCurrency,
        'to': toCurrency,
      },
    );
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }
}
