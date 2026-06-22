import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists & exposes the user's preferred app language. A `null` locale means
/// "follow the device" (the default). Setting one (e.g. Arabic) overrides it
/// app-wide and flips the layout to RTL automatically via Flutter's
/// [Directionality].
///
/// Mirrors [ThemeModeController]: StateNotifier + SharedPreferences, web + mobile.
///
/// Supported here: en (English), hi (हिन्दी), ar (العربية, RTL), sw (Kiswahili).
/// Add a code here + an `app_<code>.arb` to ship a new language.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  static const _key = 'katasticho_locale';

  /// Languages offered in the in-app switcher (label shown in its own script).
  static const Map<String, String> supported = {
    'en': 'English',
    'hi': 'हिन्दी',
    'ar': 'العربية',
    'sw': 'Kiswahili',
  };

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && supported.containsKey(code)) {
        state = Locale(code);
      }
    } catch (e) {
      debugPrint('[Locale] failed to load: $e');
    }
  }

  /// Set the app language. Pass null to revert to the device locale.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (e) {
      debugPrint('[Locale] failed to persist: $e');
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});
