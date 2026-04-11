import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

/// Payments list for a specific invoice.
/// This is typically shown within the Invoice Detail screen's Payments tab,
/// but can also be navigated to standalone.
class PaymentListScreen extends ConsumerWidget {
  final String invoiceId;
  final List<Map<String, dynamic>>? payments;

  const PaymentListScreen({
    super.key,
    required this.invoiceId,
    this.payments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentList = payments ?? [];

    if (paymentList.isEmpty) {
      return const KEmptyState(
        icon: Icons.payments_outlined,
        title: 'No payments recorded',
        subtitle: 'Record a payment to track collections',
      );
    }

    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: paymentList.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (context, index) {
        final payment = paymentList[index];
        return _PaymentCard(payment: payment);
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final paymentNumber = payment['paymentNumber'] as String? ?? '--';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final method = payment['paymentMethod'] as String? ?? 'OTHER';
    final date = payment['paymentDate'] as String?;
    final reference = payment['referenceNumber'] as String?;

    return KCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: KColors.success.withValues(alpha: 0.1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Icon(
              _methodIcon(method),
              color: KColors.success,
              size: 24,
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paymentNumber, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Row(
                  children: [
                    KStatusChip(status: 'PAID', label: _methodLabel(method)),
                    if (date != null) ...[
                      KSpacing.hGapSm,
                      Text(date, style: KTypography.bodySmall),
                    ],
                  ],
                ),
                if (reference != null && reference.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Ref: $reference',
                    style: KTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatIndian(amount),
            style: KTypography.amountMedium.copyWith(
              color: KColors.success,
            ),
          ),
        ],
      ),
    );
  }

  IconData _methodIcon(String method) {
    return switch (method) {
      'CASH' => Icons.money,
      'BANK_TRANSFER' => Icons.account_balance,
      'UPI' => Icons.qr_code,
      'CHEQUE' => Icons.receipt,
      'CARD' => Icons.credit_card,
      _ => Icons.payments,
    };
  }

  String _methodLabel(String method) {
    return switch (method) {
      'CASH' => 'Cash',
      'BANK_TRANSFER' => 'Bank',
      'UPI' => 'UPI',
      'CHEQUE' => 'Cheque',
      'CARD' => 'Card',
      _ => 'Other',
    };
  }
}
