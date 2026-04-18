import 'package:flutter/material.dart';

/// Katasticho brand & semantic color tokens — **Katasticho 2026** palette.
///
/// Theme-aware surfaces, text and primaries are owned by [ThemeData] /
/// [ColorScheme] (built via FlexColorScheme in `k_theme.dart`). Pull those
/// from `Theme.of(context).colorScheme`.
///
/// This file only holds:
///   • The brand seed color (used by both light & dark themes)
///   • Semantic colors that are SAME in light & dark (status, ageing, etc.)
///   • Legacy aliases for widgets that haven't been migrated to Theme.of()
///
/// Palette — **Indigo + slate** (professional, finance-grade, 2026-era).
/// Indigo conveys trust without looking like QuickBooks green or Zoho red.
class KColors {
  KColors._();

  // ── Brand seed ────────────────────────────────────────────────────
  /// Indigo-600 — trustworthy, finance-grade primary.
  static const Color brandSeed = Color(0xFF4F46E5);

  // Legacy convenience aliases — light-mode values.
  static const Color primary = Color(0xFF4F46E5);        // indigo-600
  static const Color primaryHover = Color(0xFF4338CA);   // indigo-700
  static const Color primaryPressed = Color(0xFF3730A3); // indigo-800
  static const Color primaryLight = Color(0xFF818CF8);   // indigo-400
  static const Color primarySoft = Color(0xFFEEF2FF);    // indigo-50
  static const Color onPrimary = Colors.white;

  static const Color secondary = Color(0xFF0EA5E9);      // sky-500 — cool accent
  static const Color secondarySoft = Color(0xFFE0F2FE);  // sky-100
  static const Color onSecondary = Colors.white;

  static const Color accent = Color(0xFFF59E0B);         // amber-500
  static const Color accentSoft = Color(0xFFFEF3C7);     // amber-100

  // ── Semantic — same in light & dark ──
  static const Color success = Color(0xFF059669);        // emerald-600
  static const Color successLight = Color(0xFFD1FAE5);   // emerald-100
  static const Color warning = Color(0xFFD97706);        // amber-600
  static const Color warningLight = Color(0xFFFEF3C7);   // amber-100
  static const Color error = Color(0xFFDC2626);          // rose-600
  static const Color errorLight = Color(0xFFFEE2E2);     // rose-100
  static const Color info = Color(0xFF2563EB);           // blue-600
  static const Color infoLight = Color(0xFFDBEAFE);      // blue-100

  // ── Financial Status ──
  static const Color paid = Color(0xFF059669);
  static const Color paidBg = Color(0xFFD1FAE5);
  static const Color partiallyPaid = Color(0xFFD97706);
  static const Color partiallyPaidBg = Color(0xFFFEF3C7);
  static const Color overdue = Color(0xFFDC2626);
  static const Color overdueBg = Color(0xFFFEE2E2);
  static const Color draft = Color(0xFF64748B);
  static const Color draftBg = Color(0xFFF1F5F9);
  static const Color sent = Color(0xFF4F46E5);           // matches new brand
  static const Color sentBg = Color(0xFFEEF2FF);
  static const Color cancelled = Color(0xFF475569);
  static const Color cancelledBg = Color(0xFFE2E8F0);

  // ── Ageing Report Colors ──
  static const Color ageingCurrent = Color(0xFF059669);
  static const Color ageing1to30 = Color(0xFF2563EB);
  static const Color ageing31to60 = Color(0xFFD97706);
  static const Color ageing61to90 = Color(0xFFEA580C);
  static const Color ageing90Plus = Color(0xFFDC2626);

  // ── Legacy neutral aliases — light-mode values, kept for compat ──
  // Prefer Theme.of(context).colorScheme.surface / onSurface in new code.
  static const Color background = Color(0xFFF8FAFC);     // slate-50
  static const Color backgroundAlt = Color(0xFFF1F5F9);  // slate-100
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color divider = Color(0xFFE2E8F0);        // slate-200
  static const Color dividerSoft = Color(0xFFF1F5F9);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color textPrimary = Color(0xFF0F172A);    // slate-900
  static const Color textSecondary = Color(0xFF475569);  // slate-600
  static const Color textTertiary = Color(0xFF64748B);   // slate-500
  static const Color textHint = Color(0xFF94A3B8);       // slate-400
  static const Color textOnDark = Colors.white;

  // ── Gradients ──
  /// Indigo → violet primary banner.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  /// Indigo → sky brand gradient for hero areas.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
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
