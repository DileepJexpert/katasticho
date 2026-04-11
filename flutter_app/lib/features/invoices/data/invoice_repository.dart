import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(apiClientProvider));
});

class InvoiceRepository {
  final ApiClient _api;

  InvoiceRepository(this._api);

  Future<Map<String, dynamic>> listInvoices({
    int page = 0,
    int size = 20,
    String? status,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
      if (search != null) 'search': search,
    };
    final response = await _api.get(ApiConfig.invoices, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final response = await _api.get(ApiConfig.invoiceById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.invoices, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendInvoice(String id) async {
    final response = await _api.post(ApiConfig.sendInvoice(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelInvoice(String id) async {
    final response = await _api.post(ApiConfig.cancelInvoice(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordPayment(
      String invoiceId, Map<String, dynamic> data) async {
    final response = await _api.post(
      ApiConfig.invoicePayments(invoiceId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }
}
