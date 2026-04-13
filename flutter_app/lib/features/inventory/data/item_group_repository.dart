import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Repository for F5 item groups. Mirrors [ItemRepository] in shape:
/// returns the raw [Map] from the server (already containing
/// `data` + `message` keys) and lets the screens unwrap. Errors are
/// rethrown — UI handles the snackbar.
final itemGroupRepositoryProvider = Provider<ItemGroupRepository>((ref) {
  return ItemGroupRepository(ref.watch(apiClientProvider));
});

class ItemGroupRepository {
  final ApiClient _api;

  ItemGroupRepository(this._api);

  Future<Map<String, dynamic>> listGroups({int page = 0, int size = 50}) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    debugPrint('[ItemGroupRepo] listGroups params=$params');
    try {
      final response = await _api.get(ApiConfig.itemGroups, queryParameters: params);
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[ItemGroupRepo] listGroups FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getGroup(String id) async {
    final response = await _api.get(ApiConfig.itemGroupById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    debugPrint('[ItemGroupRepo] createGroup data=$data');
    final response = await _api.post(ApiConfig.itemGroups, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroup(
      String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.itemGroupById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGroup(String id) async {
    await _api.delete(ApiConfig.itemGroupById(id));
  }

  /// Variants under a group, ordered by SKU. Returns the full
  /// [List] of item maps (the controller bypasses pagination — group
  /// child counts are small in v1).
  Future<List<dynamic>> listVariants(String id) async {
    final response = await _api.get(ApiConfig.itemGroupVariants(id));
    final body = response.data as Map<String, dynamic>;
    final content = body['data'];
    return content is List ? content : <dynamic>[];
  }

  /// Matrix bulk-create. [combinations] is a list of attribute maps
  /// like `[{size: S, color: Red}, {size: M, color: Red}]`. The server
  /// is idempotent — combos that already exist as live variants are
  /// reported in `skippedReasons` rather than failing the batch.
  Future<Map<String, dynamic>> generateVariants(
    String groupId,
    List<Map<String, String>> combinations,
  ) async {
    debugPrint('[ItemGroupRepo] generateVariants groupId=$groupId combos=${combinations.length}');
    final response = await _api.post(
      ApiConfig.generateVariants(groupId),
      data: {'combinations': combinations},
    );
    return response.data as Map<String, dynamic>;
  }
}

// ────────────────────────────────────────────────────────────────────
// Providers
// ────────────────────────────────────────────────────────────────────

/// Paged list of item groups. Not autoDispose because the picker on
/// the item create screen needs to share state with the list screen.
final itemGroupListProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(itemGroupRepositoryProvider);
  return repo.listGroups();
});

final itemGroupDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(itemGroupRepositoryProvider);
  return repo.getGroup(id);
});

final itemGroupVariantsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, groupId) async {
  final repo = ref.watch(itemGroupRepositoryProvider);
  return repo.listVariants(groupId);
});
