import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Thin Dio wrapper over the v2 F4 BOM endpoints. The resolver that
/// explodes composites at invoice-send time is server-side — this
/// client only powers the CRUD screens on the item detail view.
final bomRepositoryProvider = Provider<BomRepository>((ref) {
  return BomRepository(ref.watch(apiClientProvider));
});

class BomRepository {
  final ApiClient _api;

  BomRepository(this._api);

  /// Enriched listing — each row carries `childSku` + `childName` so
  /// the UI can render "2 × WIDGET-BLUE" without an N+1 fetch.
  Future<List<Map<String, dynamic>>> listComponents(String parentId) async {
    debugPrint('[BomRepo] listComponents parent=$parentId');
    final response = await _api.get(ApiConfig.itemBom(parentId));
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addComponent(
    String parentId, {
    required String childItemId,
    required num quantity,
  }) async {
    final payload = <String, dynamic>{
      'childItemId': childItemId,
      'quantity': quantity,
    };
    debugPrint('[BomRepo] addComponent parent=$parentId payload=$payload');
    final response =
        await _api.post(ApiConfig.itemBom(parentId), data: payload);
    final body = response.data as Map<String, dynamic>;
    return (body['data'] ?? body) as Map<String, dynamic>;
  }

  Future<void> deleteComponent(String componentId) async {
    debugPrint('[BomRepo] deleteComponent id=$componentId');
    await _api.delete(ApiConfig.itemBomComponentById(componentId));
  }
}

/// BOM rows for one parent — autoDispose.family so the list is
/// per-item and invalidated on add/delete.
final bomComponentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, parentId) async {
  final repo = ref.watch(bomRepositoryProvider);
  return repo.listComponents(parentId);
});
