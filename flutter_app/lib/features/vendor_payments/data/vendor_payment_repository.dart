import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final vendorPaymentRepositoryProvider =
    Provider<VendorPaymentRepository>((ref) {
  return VendorPaymentRepository(ref.watch(apiClientProvider));
});

class VendorPaymentRepository {
  final ApiClient _api;

  VendorPaymentRepository(this._api);

  Future<Map<String, dynamic>> listPayments({
    int page = 0,
    int size = 20,
    String? contactId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (contactId != null) 'contact_id': contactId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    };
    final response =
        await _api.get(ApiConfig.vendorPayments, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayment(String id) async {
    final response = await _api.get(ApiConfig.vendorPaymentById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> voidPayment(String id) async {
    final response =
        await _api.post(ApiConfig.voidVendorPayment(id));
    return response.data as Map<String, dynamic>;
  }
}
