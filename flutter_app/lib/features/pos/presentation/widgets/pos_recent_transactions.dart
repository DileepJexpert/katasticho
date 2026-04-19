import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_recent_transactions.dart';

Future<Map<String, String>?> showRecentTransactionsSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    builder: (_) => const _RecentTransactionsSheetContent(),
  );
}

class _RecentTransactionsSheetContent extends ConsumerWidget {
  const _RecentTransactionsSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 20),
                KSpacing.hGapSm,
                Text('Recent Transactions', style: KTypography.h3),
              ],
            ),
            KSpacing.vGapMd,
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 48, color: cs.outlineVariant),
                    KSpacing.vGapSm,
                    Text('No recent transactions',
                        style: KTypography.bodyMedium
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              )
            else
              ...transactions.map((tx) => _RecentTransactionTile(
                    transaction: tx,
                    onReprint: () {
                      Navigator.pop(
                          context, {'action': 'print', 'receiptId': tx.receiptId});
                    },
                    onWhatsApp: () {
                      Navigator.pop(context,
                          {'action': 'whatsapp', 'receiptId': tx.receiptId});
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  final RecentTransaction transaction;
  final VoidCallback onReprint;
  final VoidCallback onWhatsApp;

  const _RecentTransactionTile({
    required this.transaction,
    required this.onReprint,
    required this.onWhatsApp,
  });

  IconData _paymentModeIcon(String mode) {
    return switch (mode.toUpperCase()) {
      'CASH' => Icons.payments_outlined,
      'UPI' => Icons.qr_code,
      'CARD' => Icons.credit_card,
      _ => Icons.payment,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ago = DateTime.now().difference(transaction.completedAt);
    final agoText = ago.inMinutes < 1
        ? 'just now'
        : ago.inMinutes < 60
            ? '${ago.inMinutes}m ago'
            : '${ago.inHours}h ago';

    final paymentLabel = transaction.paymentMode.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(transaction.receiptNumber,
                          style: KTypography.labelMedium),
                      KSpacing.hGapSm,
                      Text(
                        agoText,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.customerName ?? 'Walk-in',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(_paymentModeIcon(paymentLabel), size: 16,
                color: KColors.textSecondary),
            const SizedBox(width: 4),
            Text(paymentLabel,
                style: KTypography.labelSmall
                    .copyWith(color: KColors.textSecondary)),
            KSpacing.hGapMd,
            Text(
              CurrencyFormatter.formatIndian(transaction.total),
              style: KTypography.amountSmall,
            ),
            KSpacing.hGapSm,
            IconButton(
              icon: const Icon(Icons.print, size: 18),
              onPressed: onReprint,
              tooltip: 'Reprint',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.send, size: 18),
              onPressed: onWhatsApp,
              tooltip: 'WhatsApp',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
