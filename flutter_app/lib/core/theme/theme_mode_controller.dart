import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists & exposes the user's preferred [ThemeMode] (system / light / dark).
///
/// Stored in SharedPreferences (works on web + mobile, no secure-storage
/// crypto pitfalls). Defaults to [ThemeMode.system] until the user picks one.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'katasticho_theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      debugPrint('[ThemeMode] loaded from prefs: $stored');
      if (stored != null) {
        state = ThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      debugPrint('[ThemeMode] failed to load: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    debugPrint('[ThemeMode] setMode -> ${mode.name}');
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      debugPrint('[ThemeMode] failed to persist: $e');
    }
  }

  /// Cycles through system → light → dark → system.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});
