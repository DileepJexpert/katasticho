import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.watch(apiClientProvider));
});

class ItemRepository {
  final ApiClient _api;

  ItemRepository(this._api);

  Future<Map<String, dynamic>> listItems({
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
    debugPrint('[ItemRepo] listItems params=$params');
    try {
      final response = await _api.get(ApiConfig.items, queryParameters: params);
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[ItemRepo] listItems FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getItem(String id) async {
    final response = await _api.get(ApiConfig.itemById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    debugPrint('[ItemRepo] createItem data=$data');
    final response = await _api.post(ApiConfig.items, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateItem(
      String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.itemById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteItem(String id) async {
    await _api.delete(ApiConfig.itemById(id));
  }

  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.stockAdjust, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getItemMovements(String itemId) async {
    final response = await _api.get(ApiConfig.itemMovements(itemId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLowStock() async {
    final response = await _api.get(ApiConfig.lowStock);
    return response.data as Map<String, dynamic>;
  }
}

/// Item list — autoDispose so the search query state stays per-screen.
final itemListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, search) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.listItems(search: search);
});

final itemDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.getItem(id);
});

final lowStockProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.getLowStock();
});
