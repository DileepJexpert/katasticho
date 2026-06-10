import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_client.dart';
import 'pos_favourites.dart';
import 'pos_repository.dart';

/// POS search results — re-fetches when query changes.
final posSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, query) async {
  if (query == null || query.trim().isEmpty) return [];
  final repo = ref.watch(posRepositoryProvider);
  return repo.posSearch(query: query.trim());
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
