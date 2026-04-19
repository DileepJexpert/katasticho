import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'pos_favourite_items';

class PosFavouritesNotifier extends StateNotifier<Set<String>> {
  PosFavouritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefKey) ?? [];
    state = ids.toSet();
  }

  Future<void> toggle(String itemId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(itemId)) {
      updated.remove(itemId);
    } else {
      updated.add(itemId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, updated.toList());
  }

  bool isFavourite(String itemId) => state.contains(itemId);
}

final posFavouritesProvider =
    StateNotifierProvider<PosFavouritesNotifier, Set<String>>((ref) {
  return PosFavouritesNotifier();
});
