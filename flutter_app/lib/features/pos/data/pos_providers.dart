import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_repository.dart';

/// POS search results — re-fetches when query changes.
final posSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, query) async {
  if (query == null || query.trim().isEmpty) return [];
  final repo = ref.watch(posRepositoryProvider);
  return repo.posSearch(query: query.trim());
});
