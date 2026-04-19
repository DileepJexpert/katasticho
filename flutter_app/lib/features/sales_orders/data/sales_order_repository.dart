import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final salesOrderRepositoryProvider = Provider<SalesOrderRepository>((ref) {
  return SalesOrderRepository(ref.watch(apiClientProvider));
});

class SalesOrderRepository {
  final ApiClient _api;

  SalesOrderRepository(this._api);

  Future<Map<String, dynamic>> listSalesOrders({
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
    final response = await _api.get(ApiConfig.salesOrders, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSalesOrder(String id) async {
    final response = await _api.get(ApiConfig.salesOrderById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSalesOrder(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.salesOrders, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmSalesOrder(String id) async {
    final response = await _api.post(ApiConfig.confirmSalesOrder(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelSalesOrder(String id) async {
    final response = await _api.post(ApiConfig.cancelSalesOrder(id));
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteSalesOrder(String id) async {
    await _api.delete(ApiConfig.salesOrderById(id));
  }

  Future<Map<String, dynamic>> convertToInvoice(
      String id, Map<String, dynamic> data) async {
    final response = await _api.post(
      ApiConfig.convertSalesOrderToInvoice(id),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReservations(String id) async {
    final response = await _api.get(ApiConfig.salesOrderReservations(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLinkedInvoices(String id) async {
    final response = await _api.get(ApiConfig.salesOrderInvoices(id));
    return response.data as Map<String, dynamic>;
  }
}
