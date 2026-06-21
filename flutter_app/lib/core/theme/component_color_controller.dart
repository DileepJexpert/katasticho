import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-component accent-colour overrides — lets a user paint an individual
/// dashboard card / KPI tile a colour that differs from the global theme,
/// the way the hospital-OS dashboard does.
///
/// Keyed by a stable string id the widget passes (e.g. `"dashboard.sales"`).
/// The map is persisted to SharedPreferences so the choice survives a reload.
/// A `null`/absent entry means "use the theme" — the default for every
/// component that doesn't opt in, so this layer is purely additive.
///
/// Mirrors [ThemeModeController]: StateNotifier + SharedPreferences, no
/// secure-storage crypto pitfalls, works on web + mobile.
class ComponentColorController extends StateNotifier<Map<String, Color>> {
  ComponentColorController() : super(const {}) {
    _load();
  }

  static const _key = 'katasticho_component_colors';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key);
      if (stored == null) return;
      final map = <String, Color>{};
      for (final entry in stored) {
        // each entry is "id=AARRGGBB"
        final i = entry.indexOf('=');
        if (i <= 0) continue;
        final id = entry.substring(0, i);
        final value = int.tryParse(entry.substring(i + 1), radix: 16);
        if (value != null) map[id] = Color(value);
      }
      state = map;
    } catch (e) {
      debugPrint('[ComponentColors] failed to load: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.entries
          .map((e) =>
              '${e.key}=${e.value.toARGB32().toRadixString(16).padLeft(8, '0')}')
          .toList();
      await prefs.setStringList(_key, list);
    } catch (e) {
      debugPrint('[ComponentColors] failed to persist: $e');
    }
  }

  /// The override for [id], or null if the component should use the theme.
  Color? colorFor(String id) => state[id];

  /// Paint component [id] with [color].
  Future<void> setColor(String id, Color color) async {
    state = {...state, id: color};
    await _persist();
  }

  /// Drop the override for [id] — the component reverts to the theme.
  Future<void> clear(String id) async {
    if (!state.containsKey(id)) return;
    final next = {...state}..remove(id);
    state = next;
    await _persist();
  }

  /// Reset every override (e.g. a "restore defaults" button).
  Future<void> clearAll() async {
    state = const {};
    await _persist();
  }
}

final componentColorProvider =
    StateNotifierProvider<ComponentColorController, Map<String, Color>>((ref) {
  return ComponentColorController();
});
