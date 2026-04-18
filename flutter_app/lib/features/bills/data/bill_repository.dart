import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository(ref.watch(apiClientProvider));
});

class BillRepository {
  final ApiClient _api;

  BillRepository(this._api);

  Future<Map<String, dynamic>> listBills({
    int page = 0,
    int size = 20,
    String? status,
    String? contactId,
    String? branchId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
      if (contactId != null) 'contact_id': contactId,
      if (branchId != null) 'branch_id': branchId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (search != null) 'search': search,
    };
    final response = await _api.get(ApiConfig.bills, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBill(String id) async {
    final response = await _api.get(ApiConfig.billById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.bills, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBill(
      String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.billById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteBill(String id) async {
    final response = await _api.delete(ApiConfig.billById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postBill(String id) async {
    final response = await _api.post(ApiConfig.postBill(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> voidBill(String id, {String? reason}) async {
    final response = await _api.post(
      ApiConfig.voidBill(id),
      data: reason != null ? {'reason': reason} : null,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkPost(List<String> ids) async {
    final response = await _api.post(
      ApiConfig.bulkPostBills,
      data: {'ids': ids},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkVoid(
    List<String> ids, {
    String reason = 'Bulk voided',
  }) async {
    final response = await _api.post(
      ApiConfig.bulkVoidBills,
      data: {'ids': ids, 'reason': reason},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBillPayments(String id) async {
    final response = await _api.get(ApiConfig.billPayments(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordPayment(
      Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiConfig.vendorPayments, data: data);
    return response.data as Map<String, dynamic>;
  }
}
