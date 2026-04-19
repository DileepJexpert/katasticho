import 'package:flutter/material.dart';

/// Katasticho brand & semantic color tokens — **Katasticho 2026** palette.
///
/// ### One-line theme change
/// Change [brandSeed] to re-theme the entire app. All derived colors
/// ([primaryLight], [primarySoft], [primaryDark], gradients) and the
/// Material [ColorScheme] (via `k_theme.dart`) recompute automatically.
///
/// For secondary/tertiary accents, change [secondarySeed] / [accentSeed].
///
/// ### In widgets
/// Prefer `context.cs.primary` (see [KBuildContext] extension) for colors
/// that must adapt to light & dark mode. The static aliases below are
/// light-mode convenience shortcuts derived from the seeds.
class KColors {
  KColors._();

  // ── Brand seeds — change THESE to re-theme the entire app ─────────
  static const Color brandSeed = Color(0xFF4F46E5);     // indigo-600
  static const Color secondarySeed = Color(0xFF0EA5E9); // sky-500
  static const Color accentSeed = Color(0xFFF59E0B);    // amber-500

  // ── Primary palette (all derived from brandSeed) ──────────────────
  static const Color primary = brandSeed;
  static final Color primaryLight = _lighten(brandSeed, 0.25);
  static final Color primarySoft = _tint(brandSeed, 0.92);
  static final Color primaryDark = _lighten(brandSeed, 0.25);

  // ── Secondary palette (derived from secondarySeed) ────────────────
  static const Color secondary = secondarySeed;
  static final Color secondaryDark = _lighten(secondarySeed, 0.15);

  // ── Accent/Tertiary palette (derived from accentSeed) ─────────────
  static const Color accent = accentSeed;
  static final Color accentDark = _lighten(accentSeed, 0.10);

  // ── Semantic — fixed across all themes ──
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
  static const Color sent = brandSeed;
  static final Color sentBg = _tint(brandSeed, 0.92);
  static const Color cancelled = Color(0xFF475569);
  static const Color cancelledBg = Color(0xFFE2E8F0);

  // ── Ageing Report Colors ──
  static const Color ageingCurrent = Color(0xFF059669);
  static const Color ageing1to30 = Color(0xFF2563EB);
  static const Color ageing31to60 = Color(0xFFD97706);
  static const Color ageing61to90 = Color(0xFFEA580C);
  static const Color ageing90Plus = Color(0xFFDC2626);

  // ── Neutral aliases — light-mode values ──
  // For dark-mode support, use context.cs.surface / context.cs.onSurface.
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);        // slate-200
  static const Color textPrimary = Color(0xFF0F172A);    // slate-900
  static const Color textSecondary = Color(0xFF475569);  // slate-600
  static const Color textHint = Color(0xFF94A3B8);       // slate-400

  // ── Gradients (derived from seeds) ──
  static final LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_lighten(brandSeed, 0.08), brandSeed],
  );

  static final LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandSeed, secondarySeed],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  // ── Palette helpers ──────────────────────────────────────────────

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _tint(Color c, double factor) =>
      Color.lerp(c, Colors.white, factor)!;

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

/// Quick access to the current [ColorScheme] — avoids the verbose
/// `Theme.of(context).colorScheme` in every build method.
///
/// ```dart
/// final primary = context.cs.primary;
/// final onSurface = context.cs.onSurface;
/// ```
extension KBuildContext on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
}
