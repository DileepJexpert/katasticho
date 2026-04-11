import 'package:flutter/material.dart';

/// Katasticho ERP color palette.
/// Primary: Deep Indigo — trust, professionalism
/// Secondary: Teal — growth, financial health
/// Accent: Amber — attention, highlights
class KColors {
  KColors._();

  // ── Primary (Deep Indigo) ──
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF534BAE);
  static const Color primaryDark = Color(0xFF000051);
  static const Color onPrimary = Colors.white;

  // ── Secondary (Teal) ──
  static const Color secondary = Color(0xFF00695C);
  static const Color secondaryLight = Color(0xFF439889);
  static const Color secondaryDark = Color(0xFF003D33);
  static const Color onSecondary = Colors.white;

  // ── Accent (Amber) ──
  static const Color accent = Color(0xFFFF8F00);
  static const Color accentLight = Color(0xFFFFC046);
  static const Color accentDark = Color(0xFFC56000);

  // ── Semantic ──
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF57F17);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ── Financial Status ──
  static const Color paid = Color(0xFF2E7D32);
  static const Color paidBg = Color(0xFFE8F5E9);
  static const Color partiallyPaid = Color(0xFFF57F17);
  static const Color partiallyPaidBg = Color(0xFFFFF8E1);
  static const Color overdue = Color(0xFFC62828);
  static const Color overdueBg = Color(0xFFFFEBEE);
  static const Color draft = Color(0xFF757575);
  static const Color draftBg = Color(0xFFF5F5F5);
  static const Color sent = Color(0xFF1565C0);
  static const Color sentBg = Color(0xFFE3F2FD);
  static const Color cancelled = Color(0xFF424242);
  static const Color cancelledBg = Color(0xFFEEEEEE);

  // ── Neutrals ──
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFFAFAFA);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);

  // ── Text ──
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnDark = Colors.white;

  // ── Ageing Report Colors ──
  static const Color ageingCurrent = Color(0xFF2E7D32);
  static const Color ageing1to30 = Color(0xFF1565C0);
  static const Color ageing31to60 = Color(0xFFF57F17);
  static const Color ageing61to90 = Color(0xFFE65100);
  static const Color ageing90Plus = Color(0xFFC62828);

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
