import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/sales_receipt_providers.dart';

class PosRecentBills extends ConsumerWidget {
  const PosRecentBills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(recentPosReceiptsProvider);
    final cs = Theme.of(context).colorScheme;

    return receiptsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (receipts) {
        if (receipts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Recent Bills',
                      style: KTypography.labelMedium
                          .copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/sales-receipts'),
                    child: Text('View All',
                        style: KTypography.labelSmall
                            .copyWith(color: cs.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...receipts.map((r) => _RecentBillRow(receipt: r)),
            ],
          ),
        );
      },
    );
  }
}

class _RecentBillRow extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const _RecentBillRow({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = receipt['id']?.toString() ?? '';
    final receiptNumber = receipt['receiptNumber']?.toString() ?? '';
    final total = (receipt['total'] as num?)?.toDouble() ?? 0;
    final paymentMode = receipt['paymentMode']?.toString() ?? '';
    final contactName = receipt['contactName']?.toString();
    final createdAt = receipt['createdAt']?.toString();

    String timeText = '';
    if (createdAt != null && createdAt.isNotEmpty) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        timeText = DateFormatter.time(dt.toLocal());
      }
    }

    return InkWell(
      onTap: id.isNotEmpty
          ? () => context.push('/sales-receipts/$id')
          : null,
      borderRadius: KSpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _paymentColor(paymentMode).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_paymentIcon(paymentMode),
                  size: 14, color: _paymentColor(paymentMode)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(receiptNumber, style: KTypography.labelSmall),
                  Text(
                    contactName ?? 'Walk-in',
                    style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatCompact(total),
              style: KTypography.amountSmall.copyWith(fontSize: 13),
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(timeText,
                  style: KTypography.labelSmall.copyWith(
                      color: cs.onSurfaceVariant, fontSize: 10)),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  IconData _paymentIcon(String mode) => switch (mode.toUpperCase()) {
        'CASH' => Icons.payments_outlined,
        'UPI' => Icons.qr_code,
        'CARD' => Icons.credit_card,
        _ => Icons.payment,
      };

  Color _paymentColor(String mode) => switch (mode.toUpperCase()) {
        'CASH' => KColors.success,
        'UPI' => KColors.primary,
        'CARD' => KColors.warning,
        _ => KColors.textSecondary,
      };
}
