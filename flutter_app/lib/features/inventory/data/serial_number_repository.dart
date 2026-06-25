import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final serialNumberRepositoryProvider = Provider<SerialNumberRepository>((ref) {
  return SerialNumberRepository(ref.watch(apiClientProvider));
});

/// Serial-number tracking — receive individual units against an item, then
/// mark them damaged / returned. Sale assignment happens at billing time.
class SerialNumberRepository {
  final ApiClient _api;
  SerialNumberRepository(this._api);

  /// All serials for an item (paged) — newest first as the backend returns.
  Future<List<Map<String, dynamic>>> listByItem(String itemId,
      {int page = 0, int size = 200}) async {
    final res = await _api.get(
      ApiConfig.serialNumbersByItem(itemId),
      queryParameters: {'page': page, 'size': size},
    );
    final data = res.data['data'] ?? res.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? const [] : const []);
    return content
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// IN_STOCK serials only, optionally scoped to a warehouse.
  Future<List<Map<String, dynamic>>> listAvailable(String itemId,
      {String? warehouseId}) async {
    final res = await _api.get(
      ApiConfig.serialNumbersAvailable,
      queryParameters: {
        'itemId': itemId,
        if (warehouseId != null) 'warehouseId': warehouseId,
      },
    );
    final list = (res.data['data'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// Bulk-receive serial units into stock.
  Future<List<dynamic>> receive({
    required String itemId,
    String? warehouseId,
    String? batchId,
    required List<String> serials,
  }) async {
    final res = await _api.post(ApiConfig.serialNumbersReceive, data: {
      'itemId': itemId,
      if (warehouseId != null) 'warehouseId': warehouseId,
      if (batchId != null) 'batchId': batchId,
      'serials': serials,
    });
    return (res.data['data'] as List?) ?? const [];
  }

  Future<void> markDamaged(String id, {String? notes}) async {
    await _api.post(ApiConfig.serialNumberDamage(id),
        data: notes != null && notes.isNotEmpty ? {'notes': notes} : null);
  }

  Future<void> markReturned(String id) async {
    await _api.post(ApiConfig.serialNumberReturn(id));
  }
}
