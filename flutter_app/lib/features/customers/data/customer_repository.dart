import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(apiClientProvider));
});

class CustomerRepository {
  final ApiClient _api;

  CustomerRepository(this._api);

  Future<Map<String, dynamic>> listCustomers({
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (search != null) 'search': search,
    };
    debugPrint('[CustomerRepo] listCustomers called with params: $params');
    try {
      final response =
          await _api.get(ApiConfig.customers, queryParameters: params);
      debugPrint('[CustomerRepo] listCustomers response status: ${response.statusCode}');
      debugPrint('[CustomerRepo] listCustomers response data: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[CustomerRepo] listCustomers FAILED: $e');
      debugPrint('[CustomerRepo] Stack trace: $st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    debugPrint('[CustomerRepo] getCustomer called with id: $id');
    try {
      final response = await _api.get('${ApiConfig.customers}/$id');
      debugPrint('[CustomerRepo] getCustomer response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[CustomerRepo] getCustomer FAILED: $e');
      debugPrint('[CustomerRepo] Stack trace: $st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCustomer(
      Map<String, dynamic> data) async {
    debugPrint('[CustomerRepo] createCustomer called with data: $data');
    try {
      final response = await _api.post(ApiConfig.customers, data: data);
      debugPrint('[CustomerRepo] createCustomer response status: ${response.statusCode}');
      debugPrint('[CustomerRepo] createCustomer response data: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[CustomerRepo] createCustomer FAILED: $e');
      debugPrint('[CustomerRepo] Stack trace: $st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCustomer(
      String id, Map<String, dynamic> data) async {
    debugPrint('[CustomerRepo] updateCustomer id: $id, data: $data');
    try {
      final response = await _api.put('${ApiConfig.customers}/$id', data: data);
      debugPrint('[CustomerRepo] updateCustomer response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[CustomerRepo] updateCustomer FAILED: $e');
      debugPrint('[CustomerRepo] Stack trace: $st');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    debugPrint('[CustomerRepo] deleteCustomer id: $id');
    try {
      await _api.delete('${ApiConfig.customers}/$id');
      debugPrint('[CustomerRepo] deleteCustomer success');
    } catch (e, st) {
      debugPrint('[CustomerRepo] deleteCustomer FAILED: $e');
      debugPrint('[CustomerRepo] Stack trace: $st');
      rethrow;
    }
  }
}

final customerListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  debugPrint('[CustomerListProvider] Fetching customer list...');
  final repo = ref.watch(customerRepositoryProvider);
  final result = await repo.listCustomers();
  debugPrint('[CustomerListProvider] Got result: $result');
  return result;
});
