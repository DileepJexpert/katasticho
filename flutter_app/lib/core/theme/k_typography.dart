import 'package:flutter/material.dart';
import 'k_colors.dart';

/// Typography scale for Katasticho ERP.
///
/// Inter for UI text (loaded via GoogleFonts in [KTheme]).
/// Tighter tracking on display sizes, looser on small caps labels —
/// matches modern design systems (Linear, Vercel, shadcn).
class KTypography {
  KTypography._();

  static const String _fontFamily = 'Inter';

  // ── Display ──
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: KColors.textPrimary,
    height: 1.15,
    letterSpacing: -1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: KColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.75,
  );

  // ── Headings ──
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: KColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: KColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.35,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
    height: 1.4,
    letterSpacing: -0.2,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
    height: 1.5,
    letterSpacing: -0.1,
  );

  // ── Body ──
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: KColors.textPrimary,
    height: 1.55,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: KColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KColors.textSecondary,
    height: 1.5,
  );

  // ── Labels ──
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
    height: 1.43,
    letterSpacing: -0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: KColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// All-caps utility label, slightly tracked.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: KColors.textTertiary,
    letterSpacing: 0.6,
    height: 1.4,
  );

  // ── Financial — tighter tracking, heavier weight ──
  static const TextStyle amountLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: KColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle amountMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: KColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle amountSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
    height: 1.43,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Button ──
  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.33,
  );
}
