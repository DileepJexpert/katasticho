import 'package:flutter/material.dart';

/// Katasticho ERP color palette — modern, vibrant, and confident.
///
/// Primary: Indigo 600 — trust + modernity (replaces the old deep navy)
/// Secondary: Emerald 500 — growth + financial health
/// Tertiary: Amber 500 — highlights + attention
///
/// Inspired by Tailwind / shadcn / Linear / Stripe — flatter, brighter,
/// with soft tinted surfaces and refined neutrals.
class KColors {
  KColors._();

  // ── Primary (Indigo) ──
  static const Color primary = Color(0xFF4F46E5);          // indigo-600
  static const Color primaryHover = Color(0xFF4338CA);     // indigo-700
  static const Color primaryPressed = Color(0xFF3730A3);   // indigo-800
  static const Color primaryLight = Color(0xFF818CF8);     // indigo-400
  static const Color primarySoft = Color(0xFFEEF2FF);      // indigo-50
  static const Color primarySoftBorder = Color(0xFFE0E7FF);// indigo-100
  static const Color onPrimary = Colors.white;

  // ── Secondary (Emerald) ──
  static const Color secondary = Color(0xFF10B981);        // emerald-500
  static const Color secondaryHover = Color(0xFF059669);   // emerald-600
  static const Color secondaryLight = Color(0xFF34D399);   // emerald-400
  static const Color secondarySoft = Color(0xFFECFDF5);    // emerald-50
  static const Color onSecondary = Colors.white;

  // ── Tertiary / Accent (Amber) ──
  static const Color accent = Color(0xFFF59E0B);           // amber-500
  static const Color accentHover = Color(0xFFD97706);      // amber-600
  static const Color accentLight = Color(0xFFFBBF24);      // amber-400
  static const Color accentSoft = Color(0xFFFFFBEB);       // amber-50

  // ── Semantic ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color error = Color(0xFFEF4444);            // red-500
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color info = Color(0xFF3B82F6);             // blue-500
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);

  // ── Financial Status ──
  static const Color paid = Color(0xFF059669);
  static const Color paidBg = Color(0xFFECFDF5);
  static const Color partiallyPaid = Color(0xFFD97706);
  static const Color partiallyPaidBg = Color(0xFFFFFBEB);
  static const Color overdue = Color(0xFFDC2626);
  static const Color overdueBg = Color(0xFFFEF2F2);
  static const Color draft = Color(0xFF64748B);
  static const Color draftBg = Color(0xFFF1F5F9);
  static const Color sent = Color(0xFF2563EB);
  static const Color sentBg = Color(0xFFEFF6FF);
  static const Color cancelled = Color(0xFF475569);
  static const Color cancelledBg = Color(0xFFF1F5F9);

  // ── Neutrals (slate scale — slightly cool, modern) ──
  static const Color background = Color(0xFFF8FAFC);       // slate-50
  static const Color backgroundAlt = Color(0xFFF1F5F9);    // slate-100
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color surfaceTinted = Color(0xFFFAFAFF);    // very faint indigo wash
  static const Color divider = Color(0xFFE2E8F0);          // slate-200
  static const Color dividerSoft = Color(0xFFF1F5F9);      // slate-100
  static const Color disabled = Color(0xFFCBD5E1);         // slate-300

  // ── Text ──
  static const Color textPrimary = Color(0xFF0F172A);      // slate-900
  static const Color textSecondary = Color(0xFF475569);    // slate-600
  static const Color textTertiary = Color(0xFF64748B);     // slate-500
  static const Color textHint = Color(0xFF94A3B8);         // slate-400
  static const Color textOnDark = Colors.white;

  // ── Ageing Report Colors ──
  static const Color ageingCurrent = Color(0xFF10B981);
  static const Color ageing1to30 = Color(0xFF3B82F6);
  static const Color ageing31to60 = Color(0xFFF59E0B);
  static const Color ageing61to90 = Color(0xFFF97316);
  static const Color ageing90Plus = Color(0xFFEF4444);

  // ── Gradients (modern accents for hero areas, FABs, banners) ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],        // indigo-500 → 600
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],        // indigo → violet
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
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
