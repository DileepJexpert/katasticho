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
    final response =
        await _api.get(ApiConfig.customers, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    final response = await _api.get('${ApiConfig.customers}/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.customers, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCustomer(
      String id, Map<String, dynamic> data) async {
    final response = await _api.put('${ApiConfig.customers}/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCustomer(String id) async {
    await _api.delete('${ApiConfig.customers}/$id');
  }
}

final customerListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.listCustomers();
});
