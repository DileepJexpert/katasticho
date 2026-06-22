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
  // Deep teal — reads "money / ledger / trust", clear of the overused
  // SaaS-blue and purple (design-system.md §2, --brand-600).
  static const Color brandSeed = Color(0xFF0F8576);     // teal-600 (PRIMARY)
  static const Color secondarySeed = Color(0xFF14A08C); // teal-500 (analogous accent)
  static const Color accentSeed = Color(0xFFB45309);    // muted amber (warn family)

  // ── Warm-neutral app background (design-system.md §2, --bg-app) ──
  static const Color bgApp = Color(0xFFF7F7F5);

  // ── Sidebar seed — independent from brand. Admin chrome (sidebar,
  //    nav rail) runs on its own palette so the content area can
  //    re-brand freely without fighting the navigation.
  static const Color sidebarSeed = Color(0xFF0F172A);   // slate-900
  static const Brightness sidebarBrightness = Brightness.dark;

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

  // ── Semantic — muted, not alarm-bright (design-system.md §2) ──
  static const Color success = Color(0xFF15803D);        // pos-text
  static const Color successLight = Color(0xFFE9F6EC);   // pos-bg
  static const Color warning = Color(0xFFB45309);        // warn-text
  static const Color warningLight = Color(0xFFFEF3E2);   // warn-bg
  static const Color error = Color(0xFFBE3A34);          // neg-text (muted brick, not rose)
  static const Color errorLight = Color(0xFFFCEBEA);     // neg-bg
  static const Color info = Color(0xFF1D4ED8);           // info-text
  static const Color infoLight = Color(0xFFE8EEFD);      // info-bg

  // ── Financial Status (aligned to the muted semantic palette) ──
  static const Color paid = Color(0xFF15803D);
  static const Color paidBg = Color(0xFFE9F6EC);
  static const Color partiallyPaid = Color(0xFFB45309);
  static const Color partiallyPaidBg = Color(0xFFFEF3E2);
  static const Color overdue = Color(0xFFBE3A34);
  static const Color overdueBg = Color(0xFFFCEBEA);
  static const Color draft = Color(0xFF5F5F59);          // warm text-secondary
  static const Color draftBg = Color(0xFFF3F3F1);        // warm bg-subtle
  static const Color sent = brandSeed;
  static final Color sentBg = _tint(brandSeed, 0.92);
  static const Color cancelled = Color(0xFF5F5F59);
  static const Color cancelledBg = Color(0xFFEFEFEC);

  // ── Ageing Report Colors (muted ramp) ──
  static const Color ageingCurrent = Color(0xFF15803D);
  static const Color ageing1to30 = Color(0xFF1D4ED8);
  static const Color ageing31to60 = Color(0xFFB45309);
  static const Color ageing61to90 = Color(0xFFC2410C);
  static const Color ageing90Plus = Color(0xFFBE3A34);

  // ── Neutral aliases — warm-tinted (design-system.md §2) ──
  // For dark-mode support, use context.cs.surface / context.cs.onSurface.
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE5E5E1);        // --border
  static const Color borderStrong = Color(0xFFD4D4CF);   // --border-strong
  static const Color textPrimary = Color(0xFF1A1A18);    // warm near-black
  static const Color textSecondary = Color(0xFF5F5F59);  // warm grey
  static const Color textHint = Color(0xFF94948D);       // warm muted

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
    colors: [Color(0xFF1A9D4C), Color(0xFF15803D)],
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
      'CONFIRMED' => info,
      'PARTIALLY_SHIPPED' => warning,
      'SHIPPED' => const Color(0xFF0D9488),
      'INVOICED' => paid,
      _ => _statusKeywordColor(status),
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
      'CONFIRMED' => infoLight,
      'PARTIALLY_SHIPPED' => warningLight,
      'SHIPPED' => const Color(0xFFCCFBF1),
      'INVOICED' => paidBg,
      _ => _statusKeywordBg(status),
    };
  }

  // Keyword fallbacks — applied ONLY when the exact-match switches above miss,
  // so existing statuses keep their exact colours and previously-grey statuses
  // (e.g. "Reconciled", "GST mismatch", "Pending", "Rejected") now read
  // semantically instead of falling to neutral. Purely additive.
  static Color _statusKeywordColor(String status) {
    final s = status.toLowerCase();
    if (RegExp(r'paid|received|reconcil|filed|approved|cleared|posted|active|completed|success|accept')
        .hasMatch(s)) {
      return success;
    }
    if (RegExp(r'overdue|fail|reject|error|cancel|void|bounce|expired|blocked')
        .hasMatch(s)) {
      return error;
    }
    if (RegExp(r'pending|due|mismatch|partial|hold|review|awaiting|draft|unpaid')
        .hasMatch(s)) {
      return warning;
    }
    return textSecondary;
  }

  static Color _statusKeywordBg(String status) {
    final s = status.toLowerCase();
    if (RegExp(r'paid|received|reconcil|filed|approved|cleared|posted|active|completed|success|accept')
        .hasMatch(s)) {
      return successLight;
    }
    if (RegExp(r'overdue|fail|reject|error|cancel|void|bounce|expired|blocked')
        .hasMatch(s)) {
      return errorLight;
    }
    if (RegExp(r'pending|due|mismatch|partial|hold|review|awaiting|draft|unpaid')
        .hasMatch(s)) {
      return warningLight;
    }
    return draftBg;
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
