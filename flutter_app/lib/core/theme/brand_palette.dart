import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'k_colors.dart';

/// User-switchable brand palette — drives the WHOLE app's primary colour live
/// (app bar, buttons, KPI accents, links), the way the hospital-os "Brand
/// palette" dropdown does. Distinct from:
///   • the per-component override (long-press one card) — that's local;
///   • the static re-skin (KColors.brandSeed) — that's a one-time code change.
///
/// Each palette carries a single primary seed. The Material 3 ColorScheme is
/// re-derived from it in [main.dart] via `KTheme.light(seed)` / `.dark(seed)`,
/// so picking a palette repaints the app instantly with no rebuild of any
/// feature screen.
enum BrandPalette {
  /// Default — matches the current re-skin (teal-600). "money/ledger/trust".
  teal('Katixo Teal', KColors.brandSeed),
  clinicalBlue('Clinical Blue', Color(0xFF2563EB)),
  warmAmber('Warm Amber', Color(0xFFB45309)),
  royalIndigo('Royal Indigo', Color(0xFF4F46E5));

  const BrandPalette(this.label, this.seed);

  /// Display name shown in the dropdown.
  final String label;

  /// Primary seed colour the whole ColorScheme is generated from.
  final Color seed;

  static BrandPalette byName(String? name) =>
      BrandPalette.values.firstWhere((p) => p.name == name, orElse: () => teal);
}

/// Persists & exposes the chosen [BrandPalette]. Mirrors [ThemeModeController]:
/// StateNotifier + SharedPreferences, defaults to [BrandPalette.teal] until the
/// user picks one.
class BrandPaletteController extends StateNotifier<BrandPalette> {
  BrandPaletteController() : super(BrandPalette.teal) {
    _load();
  }

  static const _key = 'katasticho_brand_palette';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored != null) state = BrandPalette.byName(stored);
    } catch (e) {
      debugPrint('[BrandPalette] failed to load: $e');
    }
  }

  Future<void> setPalette(BrandPalette palette) async {
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, palette.name);
    } catch (e) {
      debugPrint('[BrandPalette] failed to persist: $e');
    }
  }
}

final brandPaletteProvider =
    StateNotifierProvider<BrandPaletteController, BrandPalette>((ref) {
  return BrandPaletteController();
});
