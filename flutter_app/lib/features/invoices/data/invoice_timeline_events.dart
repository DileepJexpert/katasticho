import 'package:flutter/material.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_activity_timeline.dart';

/// Synthesizes [KTimelineEvent] system events from an invoice map + its
/// payments list. All events are derived from data the app already fetches —
/// no extra API call needed. When the backend adds a proper audit-log
/// endpoint, swap this out for a provider that calls it.
class InvoiceTimelineEvents {
  InvoiceTimelineEvents._();

  static List<KTimelineEvent> from(
    Map<String, dynamic> invoice,
    List<dynamic> payments,
  ) {
    final events = <KTimelineEvent>[];
    final status = invoice['status'] as String? ?? '';

    // ── Invoice created ───────────────────────────────────────
    final createdAt = _parseDate(invoice['createdAt']);
    if (createdAt != null) {
      events.add(KTimelineEvent.system(
        timestamp: createdAt,
        message: 'Invoice created',
        subtext: invoice['invoiceNumber'] as String?,
        by: invoice['createdByName'] as String?,
        icon: Icons.receipt_long_rounded,
        color: KColors.info,
      ));
    }

    // ── Invoice sent ──────────────────────────────────────────
    final sentAt = _parseDate(invoice['sentAt']);
    if (sentAt != null) {
      final email = invoice['contactEmail'] as String?;
      events.add(KTimelineEvent.system(
        timestamp: sentAt,
        message: 'Invoice sent',
        subtext: email != null ? 'To $email' : null,
        icon: Icons.send_rounded,
        color: KColors.primary,
      ));
    } else if (status == 'SENT' || status == 'PARTIALLY_PAID' ||
        status == 'PAID' || status == 'OVERDUE') {
      // sentAt not in payload — derive a best-effort timestamp from updatedAt
      final updatedAt = _parseDate(invoice['updatedAt']);
      if (updatedAt != null && updatedAt != createdAt) {
        events.add(KTimelineEvent.system(
          timestamp: updatedAt,
          message: 'Invoice sent to customer',
          icon: Icons.send_rounded,
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
          message: 'Payment of ${CurrencyFormatter.formatIndian(amount)} received',
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
      final dueDate = _parseDate(invoice['dueDate']);
      if (dueDate != null && dueDate.isBefore(DateTime.now())) {
        events.add(KTimelineEvent.system(
          timestamp: dueDate,
          message: 'Invoice became overdue',
          icon: Icons.warning_amber_rounded,
          color: KColors.error,
        ));
      }
    }

    // ── Cancelled ─────────────────────────────────────────────
    if (status == 'CANCELLED' || status == 'VOIDED') {
      final cancelledAt = _parseDate(invoice['cancelledAt']
          ?? invoice['voidedAt']
          ?? invoice['updatedAt']);
      if (cancelledAt != null) {
        events.add(KTimelineEvent.system(
          timestamp: cancelledAt,
          message: 'Invoice cancelled',
          by: invoice['cancelledByName'] as String?,
          icon: Icons.cancel_outlined,
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
