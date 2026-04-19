import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final deliveryChallanRepositoryProvider = Provider<DeliveryChallanRepository>((ref) {
  return DeliveryChallanRepository(ref.read(apiClientProvider));
});

class DeliveryChallanRepository {
  final ApiClient _api;

  DeliveryChallanRepository(this._api);

  Future<Map<String, dynamic>> listDeliveryChallans({
    int page = 0,
    int size = 20,
    String? status,
    String? search,
    String? salesOrderId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
      if (search != null) 'search': search,
      if (salesOrderId != null) 'salesOrderId': salesOrderId,
    };
    final response = await _api.get(ApiConfig.deliveryChallans, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeliveryChallan(String id) async {
    final response = await _api.get(ApiConfig.deliveryChallanById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createDeliveryChallan(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.deliveryChallans, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> dispatchChallan(String id) async {
    final response = await _api.post(ApiConfig.dispatchChallan(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deliverChallan(String id) async {
    final response = await _api.post(ApiConfig.deliverChallan(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelChallan(String id) async {
    final response = await _api.post(ApiConfig.cancelChallan(id));
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteChallan(String id) async {
    await _api.delete(ApiConfig.deliveryChallanById(id));
  }

  Future<Map<String, dynamic>> getChallansForSalesOrder(String salesOrderId) async {
    final response = await _api.get(ApiConfig.challansBySalesOrder(salesOrderId));
    return response.data as Map<String, dynamic>;
  }
}
