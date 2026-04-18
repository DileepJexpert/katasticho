import 'package:flutter/material.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_activity_timeline.dart';

/// Synthesizes [KTimelineEvent] system events from a bill map + its payments.
class BillTimelineEvents {
  BillTimelineEvents._();

  static List<KTimelineEvent> from(
    Map<String, dynamic> bill,
    List<dynamic> payments,
  ) {
    final events = <KTimelineEvent>[];
    final status = bill['status'] as String? ?? '';

    // ── Bill created ──────────────────────────────────────────
    final createdAt = _parseDate(bill['createdAt']);
    if (createdAt != null) {
      events.add(KTimelineEvent.system(
        timestamp: createdAt,
        message: 'Bill created',
        subtext: bill['billNumber'] as String?
            ?? bill['vendorBillNumber'] as String?,
        by: bill['createdByName'] as String?,
        icon: Icons.receipt_outlined,
        color: KColors.info,
      ));
    }

    // ── Bill posted ───────────────────────────────────────────
    final postedAt = _parseDate(bill['postedAt']);
    if (postedAt != null) {
      events.add(KTimelineEvent.system(
        timestamp: postedAt,
        message: 'Bill posted to accounts payable',
        by: bill['postedByName'] as String?,
        icon: Icons.check_circle_outline_rounded,
        color: KColors.primary,
      ));
    } else if (status == 'OPEN' || status == 'PARTIALLY_PAID' ||
        status == 'PAID' || status == 'OVERDUE') {
      final updatedAt = _parseDate(bill['updatedAt']);
      if (updatedAt != null && updatedAt != createdAt) {
        events.add(KTimelineEvent.system(
          timestamp: updatedAt,
          message: 'Bill posted',
          icon: Icons.check_circle_outline_rounded,
          color: KColors.primary,
        ));
      }
    }

    // ── Payments ──────────────────────────────────────────────
    for (final p in payments) {
      final pm = p as Map<String, dynamic>;
      final paidAt = _parseDate(pm['paymentDate'] as String?
          ?? pm['createdAt'] as String?);
      final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
      final method = _methodLabel(pm['paymentMethod'] as String?);
      final ref = pm['referenceNumber'] as String?;
      if (paidAt != null) {
        events.add(KTimelineEvent.system(
          timestamp: paidAt,
          message: 'Payment of ${CurrencyFormatter.formatIndian(amount)} made',
          subtext: [method, if (ref != null && ref.isNotEmpty) 'Ref: $ref']
              .join(' • '),
          by: pm['createdByName'] as String?,
          icon: Icons.payments_rounded,
          color: KColors.success,
        ));
      }
    }

    // ── Overdue ───────────────────────────────────────────────
    if (status == 'OVERDUE') {
      final dueDate = _parseDate(bill['dueDate']);
      if (dueDate != null && dueDate.isBefore(DateTime.now())) {
        events.add(KTimelineEvent.system(
          timestamp: dueDate,
          message: 'Bill became overdue',
          icon: Icons.warning_amber_rounded,
          color: KColors.error,
        ));
      }
    }

    // ── Voided ────────────────────────────────────────────────
    if (status == 'VOID' || status == 'VOIDED') {
      final voidedAt = _parseDate(bill['voidedAt'] ?? bill['updatedAt']);
      if (voidedAt != null) {
        events.add(KTimelineEvent.system(
          timestamp: voidedAt,
          message: 'Bill voided',
          by: bill['voidedByName'] as String?,
          icon: Icons.block_rounded,
          color: KColors.error,
        ));
      }
    }

    return events;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _methodLabel(String? method) {
    return switch (method) {
      'CASH' => 'Cash',
      'BANK_TRANSFER' || 'BANK' => 'Bank transfer',
      'CHEQUE' || 'CHECK' => 'Cheque',
      'UPI' => 'UPI',
      'CARD' => 'Card',
      _ => method ?? 'Payment',
    };
  }
}
