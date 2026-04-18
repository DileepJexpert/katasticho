import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the desktop sidebar is collapsed to icon-only mode.
/// Persisted across sessions.
class SidebarCollapseController extends StateNotifier<bool> {
  SidebarCollapseController() : super(false) {
    _load();
  }

  static const _key = 'katasticho_sidebar_collapsed';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  void toggle() => _set(!state);

  Future<void> _set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}

final sidebarCollapsedProvider =
    StateNotifierProvider<SidebarCollapseController, bool>(
  (ref) => SidebarCollapseController(),
);
