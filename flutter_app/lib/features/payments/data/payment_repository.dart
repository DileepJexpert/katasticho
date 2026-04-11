import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

class PaymentRepository {
  final ApiClient _api;

  PaymentRepository(this._api);

  Future<Map<String, dynamic>> recordPayment(
      String invoiceId, Map<String, dynamic> data) async {
    final response = await _api.post(
      ApiConfig.invoicePayments(invoiceId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listPaymentsForInvoice(
      String invoiceId) async {
    final response = await _api.get(ApiConfig.invoicePayments(invoiceId));
    return response.data as Map<String, dynamic>;
  }
}
