import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Thin client over the batch REST endpoints added in v2 feature 2
/// (batch-aware selling + FEFO). The invoice line batch picker pulls
/// its list through [availableForItem]; the item detail screen will
/// eventually use [allForItem] to show batch history.
final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return BatchRepository(ref.watch(apiClientProvider));
});

class BatchRepository {
  final ApiClient _api;

  BatchRepository(this._api);

  /// FEFO-ordered list of batches that have stock on hand for the
  /// given item, from the org's default warehouse. Each element is a
  /// map containing at least: `id`, `batchNumber`, `expiryDate`
  /// (ISO `yyyy-MM-dd`), `quantityAvailable`, `unitCost`.
  ///
  /// Returns an empty list if the item has no batch stock — callers
  /// render an empty-state panel ("No batch stock available for this
  /// item — receive via GRN first").
  Future<List<Map<String, dynamic>>> availableForItem(
    String itemId, {
    String? warehouseId,
  }) async {
    final url = ApiConfig.batchesAvailable(itemId, warehouseId: warehouseId);
    debugPrint('[BatchRepo] availableForItem itemId=$itemId wh=$warehouseId');
    try {
      final response = await _api.get(url);
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'];
      if (payload is List) {
        return payload.cast<Map<String, dynamic>>();
      }
      return const [];
    } on DioException catch (e, st) {
      debugPrint('[BatchRepo] availableForItem FAILED: ${e.message}\n$st');
      rethrow;
    }
  }

  /// Every batch for an item, regardless of current on-hand. Used by
  /// the item detail screen; the FEFO invoice picker should use
  /// [availableForItem] instead so it never offers an empty batch.
  Future<List<Map<String, dynamic>>> allForItem(String itemId) async {
    try {
      final response = await _api.get(ApiConfig.batchesByItem(itemId));
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'];
      if (payload is List) {
        return payload.cast<Map<String, dynamic>>();
      }
      return const [];
    } on DioException catch (e, st) {
      debugPrint('[BatchRepo] allForItem FAILED: ${e.message}\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBatch(String id) async {
    try {
      final response = await _api.get(ApiConfig.batchById(id));
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('[BatchRepo] getBatch FAILED: ${e.message}');
      return null;
    }
  }
}
