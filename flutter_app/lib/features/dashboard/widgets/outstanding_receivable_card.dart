import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class OutstandingReceivableCard extends ConsumerWidget {
  const OutstandingReceivableCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(outstandingReceivableProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Outstanding Receivable',
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Outstanding Receivable',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (data) {
        final cs = Theme.of(context).colorScheme;

        return KCard(
          title: 'Outstanding Receivable',
          subtitle: '${data.overdueCount} overdue',
          action: TextButton(
            onPressed: () => context.push('/reports/ageing'),
            child: const Text('View All'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: KColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.formatIndian(data.totalOutstanding),
                          style: KTypography.amountMedium.copyWith(fontSize: 20),
                        ),
                        Text(
                          'total outstanding',
                          style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.overdueCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${CurrencyFormatter.formatCompact(data.overdueAmount)} overdue',
                    style: const TextStyle(fontSize: 11, color: KColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              if (data.topCustomers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text('Top Customers', style: KTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 6),
                ...data.topCustomers.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: cs.primary.withValues(alpha: 0.1),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: KTypography.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${c.invoiceCount} invoices', style: KTypography.labelSmall.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 10,
                            )),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCompact(c.outstanding),
                        style: KTypography.amountSmall.copyWith(color: KColors.warning),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }
}
