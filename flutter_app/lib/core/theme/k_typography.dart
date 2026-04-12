import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for Katasticho ERP — Manrope.
///
/// Manrope is a professional, fluidic geometric sans-serif. Used here via
/// GoogleFonts so we don't ship font files. All text colors are inherited
/// from `Theme.of(context).colorScheme.onSurface` etc — do **not** hard-code
/// foreground colors here.
class KTypography {
  KTypography._();

  // ── Display ──
  static TextStyle get displayLarge => GoogleFonts.manrope(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.0,
      );

  static TextStyle get displayMedium => GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.75,
      );

  // ── Headings ──
  static TextStyle get h1 => GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.35,
      );

  static TextStyle get h3 => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: -0.2,
      );

  static TextStyle get h4 => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.5,
        letterSpacing: -0.1,
      );

  // ── Body ──
  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
      );

  static TextStyle get bodyMedium => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  // ── Labels ──
  static TextStyle get labelLarge => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: -0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
      );

  static TextStyle get labelSmall => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.4,
      );

  // ── Financial — tighter tracking, heavier weight, tabular figures ──
  static TextStyle get amountLarge => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountMedium => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountSmall => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.43,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Button ──
  static TextStyle get button => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        height: 1.43,
      );

  static TextStyle get buttonSmall => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.33,
      );
}
