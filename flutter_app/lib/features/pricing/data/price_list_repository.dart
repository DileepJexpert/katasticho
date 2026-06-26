import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Dio repository for v2 Feature 3 (price lists). Mirrors the
/// conventions of [`CustomerRepository`]: raw `Map<String, dynamic>`
/// shuttled through, debugPrint traces on every call, rethrow on
/// error so callers can map [DioException.response.data] to the
/// backend's `BusinessException` envelope.
final priceListRepositoryProvider = Provider<PriceListRepository>((ref) {
  return PriceListRepository(ref.watch(apiClientProvider));
});

class PriceListRepository {
  final ApiClient _api;

  PriceListRepository(this._api);

  // ── Price list CRUD ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPriceLists() async {
    debugPrint('[PriceListRepo] listPriceLists');
    try {
      final response = await _api.get(ApiConfig.priceLists);
      final data = (response.data as Map<String, dynamic>)['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (e, st) {
      debugPrint('[PriceListRepo] listPriceLists FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPriceList(String id) async {
    debugPrint('[PriceListRepo] getPriceList id=$id');
    try {
      final response = await _api.get(ApiConfig.priceListById(id));
      final data = (response.data as Map<String, dynamic>)['data'];
      return data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[PriceListRepo] getPriceList FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPriceList(
      Map<String, dynamic> body) async {
    debugPrint('[PriceListRepo] createPriceList body=$body');
    try {
      final response = await _api.post(ApiConfig.priceLists, data: body);
      final data = (response.data as Map<String, dynamic>)['data'];
      return data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[PriceListRepo] createPriceList FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> deletePriceList(String id) async {
    debugPrint('[PriceListRepo] deletePriceList id=$id');
    try {
      await _api.delete(ApiConfig.priceListById(id));
    } catch (e, st) {
      debugPrint('[PriceListRepo] deletePriceList FAILED: $e\n$st');
      rethrow;
    }
  }

  // ── Price list items (tier CRUD) ───────────────────────────────────

  Future<List<Map<String, dynamic>>> listItems(String listId) async {
    debugPrint('[PriceListRepo] listItems listId=$listId');
    try {
      final response = await _api.get(ApiConfig.priceListItems(listId));
      final data = (response.data as Map<String, dynamic>)['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (e, st) {
      debugPrint('[PriceListRepo] listItems FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addItem(
      String listId, Map<String, dynamic> body) async {
    debugPrint('[PriceListRepo] addItem listId=$listId body=$body');
    try {
      final response = await _api.post(
        ApiConfig.priceListItems(listId),
        data: body,
      );
      final data = (response.data as Map<String, dynamic>)['data'];
      return data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[PriceListRepo] addItem FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteItem(String itemRowId) async {
    debugPrint('[PriceListRepo] deleteItem itemRowId=$itemRowId');
    try {
      await _api.delete(ApiConfig.priceListItemById(itemRowId));
    } catch (e, st) {
      debugPrint('[PriceListRepo] deleteItem FAILED: $e\n$st');
      rethrow;
    }
  }

  // ── Customer assignment ────────────────────────────────────────────

  /// Customers pinned to this price list.
  Future<List<Map<String, dynamic>>> listCustomers(String listId) async {
    final res = await _api.get(ApiConfig.priceListCustomers(listId));
    final data = (res.data['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> assignCustomer(String listId, String contactId) async {
    await _api.post(ApiConfig.priceListCustomerAssign(listId, contactId));
  }

  Future<void> unassignCustomer(String listId, String contactId) async {
    await _api.delete(ApiConfig.priceListCustomerAssign(listId, contactId));
  }
}

// ── Providers ────────────────────────────────────────────────────────

/// All org-scoped price lists. Used by list screen, customer
/// picker, and invoice-create customer detail pane.
final priceListsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(priceListRepositoryProvider);
  return repo.listPriceLists();
});

/// Detail + tiered items for a single list.
final priceListDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(priceListRepositoryProvider);
  return repo.getPriceList(id);
});

final priceListItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, listId) async {
  final repo = ref.watch(priceListRepositoryProvider);
  return repo.listItems(listId);
});

/// Customers pinned to a single price list.
final priceListCustomersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, listId) async {
  final repo = ref.watch(priceListRepositoryProvider);
  return repo.listCustomers(listId);
});
