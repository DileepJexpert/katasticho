import 'package:flutter/material.dart';

/// Katasticho brand & semantic color tokens.
///
/// Theme-aware surfaces, text, and primaries are owned by [ThemeData] /
/// [ColorScheme] (built via FlexColorScheme in `k_theme.dart`). Pull those
/// from `Theme.of(context).colorScheme`.
///
/// This file only holds:
///   • The brand seed color (used by both light & dark themes)
///   • Semantic colors that are SAME in light & dark (status, ageing, etc.)
///   • A few legacy aliases kept for compatibility with existing widgets.
///
/// Palette — **Sky Blue + Slate** (light, professional, fluidic).
class KColors {
  KColors._();

  // ── Brand seed ────────────────────────────────────────────────────
  /// Sky 600 — fluidic, professional, light. Drives the light ColorScheme.
  static const Color brandSeed = Color(0xFF0284C7);

  // Legacy convenience aliases — light-mode values, kept for compatibility
  // with widgets that haven't been migrated to Theme.of(context) yet.
  static const Color primary = Color(0xFF0284C7);     // sky-600
  static const Color primaryHover = Color(0xFF0369A1); // sky-700
  static const Color primaryPressed = Color(0xFF075985); // sky-800
  static const Color primaryLight = Color(0xFF38BDF8); // sky-400
  static const Color primarySoft = Color(0xFFE0F2FE);  // sky-100
  static const Color onPrimary = Colors.white;

  static const Color secondary = Color(0xFF14B8A6);     // teal-500 fluidic accent
  static const Color secondarySoft = Color(0xFFCCFBF1); // teal-100
  static const Color onSecondary = Colors.white;

  static const Color accent = Color(0xFFF59E0B);     // amber-500
  static const Color accentSoft = Color(0xFFFFFBEB); // amber-50

  // ── Semantic — same in light & dark ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFEFF6FF);

  // ── Financial Status ──
  static const Color paid = Color(0xFF059669);
  static const Color paidBg = Color(0xFFECFDF5);
  static const Color partiallyPaid = Color(0xFFD97706);
  static const Color partiallyPaidBg = Color(0xFFFFFBEB);
  static const Color overdue = Color(0xFFDC2626);
  static const Color overdueBg = Color(0xFFFEF2F2);
  static const Color draft = Color(0xFF64748B);
  static const Color draftBg = Color(0xFFF1F5F9);
  static const Color sent = Color(0xFF0284C7);   // matches brand
  static const Color sentBg = Color(0xFFE0F2FE);
  static const Color cancelled = Color(0xFF475569);
  static const Color cancelledBg = Color(0xFFF1F5F9);

  // ── Ageing Report Colors ──
  static const Color ageingCurrent = Color(0xFF10B981);
  static const Color ageing1to30 = Color(0xFF0EA5E9);
  static const Color ageing31to60 = Color(0xFFF59E0B);
  static const Color ageing61to90 = Color(0xFFF97316);
  static const Color ageing90Plus = Color(0xFFEF4444);

  // ── Legacy neutral aliases — light-mode values, kept for compat ──
  // Prefer Theme.of(context).colorScheme.surface / onSurface in new code.
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundAlt = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color dividerSoft = Color(0xFFF1F5F9);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnDark = Colors.white;

  // ── Gradients ──
  /// Sky → Indigo gradient — fluidic primary banner.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
  );

  /// Sky → Cyan brand gradient for hero areas.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF0891B2)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  /// Returns the color for a given invoice/payment status.
  static Color statusColor(String status) {
    return switch (status.toUpperCase()) {
      'PAID' => paid,
      'PARTIALLY_PAID' => partiallyPaid,
      'OVERDUE' => overdue,
      'DRAFT' => draft,
      'SENT' => sent,
      'CANCELLED' => cancelled,
      'ISSUED' => sent,
      'APPLIED' => paid,
      _ => textSecondary,
    };
  }

  /// Returns the background color for a given status chip.
  static Color statusBgColor(String status) {
    return switch (status.toUpperCase()) {
      'PAID' => paidBg,
      'PARTIALLY_PAID' => partiallyPaidBg,
      'OVERDUE' => overdueBg,
      'DRAFT' => draftBg,
      'SENT' => sentBg,
      'CANCELLED' => cancelledBg,
      'ISSUED' => sentBg,
      'APPLIED' => paidBg,
      _ => draftBg,
    };
  }
}
