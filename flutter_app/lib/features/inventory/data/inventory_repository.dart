import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(apiClientProvider));
});

/// Unified inventory repository for warehouse zones, batch traceability,
/// and other cross-cutting inventory features.
class InventoryRepository {
  final ApiClient _api;
  InventoryRepository(this._api);

  // ── Warehouses ──

  Future<List<dynamic>> getWarehouses() async {
    try {
      final res = await _api.get(ApiConfig.warehouses);
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Warehouse Zones ──

  Future<List<dynamic>> getWarehouseZones({String? warehouseId}) async {
    try {
      final url = warehouseId != null
          ? '${ApiConfig.warehouseZones}?warehouseId=$warehouseId'
          : ApiConfig.warehouseZones;
      final res = await _api.get(url);
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createWarehouseZone(
      Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.warehouseZones, data: body);
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> updateWarehouseZone(
      String id, Map<String, dynamic> body) async {
    final res = await _api.put('${ApiConfig.warehouseZones}/$id', data: body);
    final data = res.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<void> deleteWarehouseZone(String id) async {
    await _api.delete('${ApiConfig.warehouseZones}/$id');
  }

  // ── Batch Traceability ──

  Future<Map<String, dynamic>> getBatchForwardTrace(String batchId) async {
    try {
      final res = await _api.get(ApiConfig.batchTraceForward(batchId));
      final data = res.data['data'];
      if (data is Map<String, dynamic>) return data;
      return {'movements': [], 'batchId': batchId};
    } catch (_) {
      return {'movements': [], 'batchId': batchId};
    }
  }

  Future<Map<String, dynamic>> getBatchBackwardTrace(String batchId) async {
    try {
      final res = await _api.get(ApiConfig.batchTraceBackward(batchId));
      final data = res.data['data'];
      if (data is Map<String, dynamic>) return data;
      return {'movements': [], 'batchId': batchId};
    } catch (_) {
      return {'movements': [], 'batchId': batchId};
    }
  }
}
