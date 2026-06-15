import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_client.dart';
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

/// POS search results — re-fetches when query changes. Online results are
/// cached to the local catalog so the same search keeps working offline; on a
/// network failure the query falls back to the cached catalog.
final posSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, query) async {
  if (query == null || query.trim().isEmpty) return [];
  final q = query.trim();
  final repo = ref.watch(posRepositoryProvider);
  final offline = OfflinePosService.instance;
  try {
    final results = await repo.posSearch(query: q);
    offline.cacheItems(results); // fire-and-forget: keep the catalog warm
    return results;
  } catch (e) {
    if (_isNetworkError(e)) {
      return offline.searchLocalItems(q); // offline fallback
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
