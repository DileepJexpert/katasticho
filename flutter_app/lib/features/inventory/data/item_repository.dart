import 'package:dio/dio.dart';
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
    bool negativeStockOnly = false,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (search != null && search.isNotEmpty) 'search': search,
      if (activeOnly) 'activeOnly': true,
      if (negativeStockOnly) 'negativeStockOnly': true,
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

  Future<int> negativeStockCount() async {
    final response = await _api.get('${ApiConfig.items}/negative-stock/count');
    final raw = (response.data as Map<String, dynamic>)['data'];
    final count = raw is Map ? raw['count'] : null;
    return (count is num) ? count.toInt() : 0;
  }

  Future<List<Map<String, dynamic>>> listRackLocations() async {
    final response = await _api.get(ApiConfig.rackLocations);
    final raw = response.data as Map<String, dynamic>;
    final data = raw['data'] ?? raw;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listRackLocationsForWarehouse(
    String? warehouseId,
  ) async {
    final response = await _api.get(
      ApiConfig.rackLocations,
      queryParameters: {
        if (warehouseId != null && warehouseId.isNotEmpty)
          'warehouseId': warehouseId,
      },
    );
    final raw = response.data as Map<String, dynamic>;
    final data = raw['data'] ?? raw;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listWarehouses() async {
    final response = await _api.get(ApiConfig.warehouses);
    final raw = response.data as Map<String, dynamic>;
    final data = raw['data'] ?? raw;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<Map<String, dynamic>> createRackLocation(
    Map<String, dynamic> data,
  ) async {
    final response = await _api.post(ApiConfig.rackLocations, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> seedDemoRackLocations() async {
    final response = await _api.post(ApiConfig.rackLocationsSeedDemo);
    final raw = response.data as Map<String, dynamic>;
    final data = raw['data'] ?? raw;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  /// Dry-run validate the CSV. Server parses + validates every row but
  /// writes nothing. Returns an ItemImportPreview payload so the UI can
  /// render a preview table with per-row OK / ERROR status.
  Future<Map<String, dynamic>> previewImport(
    String csv, {
    String filename = 'items.csv',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromString(csv, filename: filename),
    });
    final response = await _api.dio.post(
      ApiConfig.itemImportPreview,
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Commit the bulk import. Same CSV shape as preview; persists valid
  /// rows and skips error rows (same verdicts as preview).
  Future<Map<String, dynamic>> commitImport(
    String csv, {
    String filename = 'items.csv',
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromString(csv, filename: filename),
    });
    final response = await _api.dio.post(
      ApiConfig.itemImport,
      data: form,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
    return response.data as Map<String, dynamic>;
  }
}

/// Item list — autoDispose so the search query state stays per-screen.
/// Filter key for the items list — paired so `negativeStockOnly` toggles
/// don't piggy-back on the search cache and vice-versa.
typedef ItemListFilter = ({String? search, bool negativeStockOnly});

final itemListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ItemListFilter>((ref, filter) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.listItems(
    search: filter.search,
    negativeStockOnly: filter.negativeStockOnly,
  );
});

/// Count of items with negative on-hand stock (sold without opening stock,
/// awaiting a stock receipt). Drives the "Needs stock" chip badge + dashboard tile.
final negativeStockCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.negativeStockCount();
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
