import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/pos_database.dart';
import 'offline_pos_service.dart';
import 'pos_favourites.dart';
import 'pos_repository.dart';

bool _isNetworkError(Object e) {
  if (e is! DioException) return false;
  return e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.unknown;
}

/// Drug-master catalog fallback for POS — medicines not yet in the org's
/// item master. Only fetched when the catalog section is actually built.
final posCatalogSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final repo = ref.watch(posRepositoryProvider);
  return repo.catalogSearch(query: query.trim());
});

/// POS search — **local-first**. Searches the local SQLite catalog (instant,
/// <5ms typical) and serves the result with no network in the hot path. A
/// background catalog sync ([PosCatalogSyncService]) keeps the cache fresh, so
/// the cashier never waits for the server.
///
/// If the local cache is empty (first-time setup or a wiped DB), we fall back
/// to the live API once so the cashier isn't stuck — the sync service then
/// fills the cache for next time.
///
/// Stock here is "last known": the **authoritative** check happens at receipt
/// post-time on the server, so multi-terminal selling can't oversell.
final posSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, query) async {
  if (query == null || query.trim().isEmpty) return [];
  final q = query.trim();
  final offline = OfflinePosService.instance;

  if (posOfflineSupported) {
    final local = await offline.searchLocalItems(q);
    if (local.isNotEmpty) return local;
    // Empty local cache → one-time online fallback so the counter still works
    // before the first background sync completes.
    final cached = await offline.cachedItemCount();
    if (cached > 0) {
      // Cache is populated but this query has no match locally — return empty
      // so the UI shows the "no items" state rather than masking it with a
      // possibly-stale network call.
      return const [];
    }
  }

  // Cold cache (web build, or first POS open with nothing synced yet).
  try {
    final results = await ref.watch(posRepositoryProvider).posSearch(query: q);
    offline.cacheItems(results); // warm the cache for next time
    return results;
  } catch (e) {
    if (_isNetworkError(e)) {
      return offline.searchLocalItems(q);
    }
    rethrow;
  }
});

/// Fetches UPI payment settings (upiId, displayName) from org settings.
final upiSettingsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(ApiConfig.upiSettings);
    final data = response.data as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  } catch (_) {
    return {};
  }
});

/// Fetches SMS notification settings from org settings.
final smsSettingsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(ApiConfig.smsSettings);
    final data = response.data as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  } catch (_) {
    return {};
  }
});

final whatsappSettingsProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(ApiConfig.whatsappSettings);
    final data = response.data as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  } catch (_) {
    return {};
  }
});

/// Whether this org bills freely at the POS counter — i.e. a sale is never
/// blocked for being short on stock; quantities can exceed (or start below)
/// recorded stock and simply go negative, reconciled later via a stock
/// receipt. Reads `pos.allow_negative_stock` from org settings.
///
/// Defaults to **true** (unset key returns HTTP 404 → caught here) so a fresh
/// shop can search a medicine, tap it, and bill immediately without first
/// loading opening stock for every item. A distributor that wants strict
/// stock control turns it off in POS Receipt Settings.
final posAllowNegativeStockProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response =
        await client.get('${ApiConfig.orgSettings}/pos.allow_negative_stock');
    final data = response.data as Map<String, dynamic>? ?? {};
    final raw = data['pos.allow_negative_stock']?.toString();
    if (raw == null || raw.isEmpty) return true;
    return raw.toLowerCase() != 'false';
  } catch (_) {
    return true; // unset / network error → bill freely
  }
});

/// Pharmacy Rx-enforcement mode: OFF / WARN (default for IN) / STRICT.
/// Country-driven default lives on the backend — Flutter just trusts whatever
/// the server returns. When the call fails, default to WARN so the UX doesn't
/// silently slip into STRICT (which would block sales).
final pharmaRxEnforcementModeProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response =
        await client.get('/api/v1/settings/pharma/rx-enforcement');
    final body = response.data as Map<String, dynamic>? ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    final mode = data['mode']?.toString().toUpperCase();
    if (mode == 'OFF' || mode == 'WARN' || mode == 'STRICT') return mode!;
    return 'WARN';
  } catch (_) {
    return 'WARN';
  }
});

/// Fetches item details for all favourite item IDs.
final posFavouriteItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ids = ref.watch(posFavouritesProvider);
  if (ids.isEmpty) return [];
  final repo = ref.watch(posRepositoryProvider);
  final results = <Map<String, dynamic>>[];
  for (final id in ids) {
    try {
      final items = await repo.posSearch(query: id, limit: 1);
      if (items.isNotEmpty) results.add(items.first);
    } catch (_) {}
  }
  return results;
});
