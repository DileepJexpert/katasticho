import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for Katasticho ERP — Plus Jakarta Sans.
///
/// All text colors are pulled from the active theme; do **not** hard-code
/// foreground colors here. The widgets receive theme-aware colors via
/// `Theme.of(context).colorScheme.onSurface` etc.
class KTypography {
  KTypography._();

  // ── Display ──
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.0,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.75,
      );

  // ── Headings ──
  static TextStyle get h1 => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.35,
      );

  static TextStyle get h3 => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: -0.2,
      );

  static TextStyle get h4 => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.5,
        letterSpacing: -0.1,
      );

  // ── Body ──
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  // ── Labels ──
  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: -0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      );

  /// All-caps utility label, slightly tracked.
  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.4,
      );

  // ── Financial — tighter tracking, heavier weight ──
  static TextStyle get amountLarge => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountMedium => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountSmall => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.43,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Button ──
  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        height: 1.43,
      );

  static TextStyle get buttonSmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.33,
      );
}
