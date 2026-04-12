import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(apiClientProvider));
});

class SupplierRepository {
  final ApiClient _api;

  SupplierRepository(this._api);

  Future<Map<String, dynamic>> listSuppliers({
    int page = 0,
    int size = 50,
    String? search,
    bool activeOnly = false,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (search != null && search.isNotEmpty) 'search': search,
      if (activeOnly) 'activeOnly': true,
    };
    debugPrint('[SupplierRepo] listSuppliers params=$params');
    try {
      final response =
          await _api.get(ApiConfig.suppliers, queryParameters: params);
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[SupplierRepo] listSuppliers FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSupplier(String id) async {
    final response = await _api.get(ApiConfig.supplierById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> data) async {
    debugPrint('[SupplierRepo] createSupplier data=$data');
    final response = await _api.post(ApiConfig.suppliers, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSupplier(
      String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.supplierById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteSupplier(String id) async {
    await _api.delete(ApiConfig.supplierById(id));
  }
}

/// Search-aware supplier list. The family parameter is the search query
/// (or null for "all"), so the picker sheet and the supplier list screen
/// can share the same provider with different states.
final supplierListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, search) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.listSuppliers(search: search);
});

final supplierDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSupplier(id);
});
