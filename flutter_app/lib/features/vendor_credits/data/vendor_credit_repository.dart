import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final vendorCreditRepositoryProvider =
    Provider<VendorCreditRepository>((ref) {
  return VendorCreditRepository(ref.watch(apiClientProvider));
});

class VendorCreditRepository {
  final ApiClient _api;

  VendorCreditRepository(this._api);

  Future<Map<String, dynamic>> listCredits({
    int page = 0,
    int size = 20,
    String? status,
    String? contactId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
      if (contactId != null) 'contact_id': contactId,
    };
    final response =
        await _api.get(ApiConfig.vendorCredits, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCredit(String id) async {
    final response = await _api.get(ApiConfig.vendorCreditById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCredit(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.vendorCredits, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteCredit(String id) async {
    final response = await _api.delete(ApiConfig.vendorCreditById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postCredit(String id) async {
    final response = await _api.post(ApiConfig.postVendorCredit(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> voidCredit(String id,
      {String? reason}) async {
    final response = await _api.post(
      ApiConfig.voidVendorCredit(id),
      data: reason != null ? {'reason': reason} : null,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyToBill(
      String creditId, String billId, double amount) async {
    final response = await _api.post(
      ApiConfig.applyVendorCredit(creditId),
      data: {'billId': billId, 'amount': amount},
    );
    return response.data as Map<String, dynamic>;
  }

  /// List outstanding bills for a specific vendor (for the Apply sheet).
  Future<Map<String, dynamic>> listVendorBills(String contactId) async {
    final params = <String, dynamic>{
      'contact_id': contactId,
      'status': 'OPEN',
      'size': 100,
    };
    final response =
        await _api.get(ApiConfig.bills, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }
}
