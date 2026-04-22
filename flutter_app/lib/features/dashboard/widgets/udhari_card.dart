import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class UdhariCard extends ConsumerWidget {
  const UdhariCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(arSummaryProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Udhari (Credit)',
        child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Udhari (Credit)',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (ar) {
        final cs = Theme.of(context).colorScheme;
        final hasOverdue = ar.overdueCount > 0;

        return KCard(
          title: 'Udhari (Credit)',
          subtitle: 'Customers owe you',
          action: TextButton(
            onPressed: () => context.go('/reports/ageing'),
            child: const Text('Details'),
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
                          CurrencyFormatter.formatIndian(ar.totalOutstanding),
                          style: KTypography.amountMedium.copyWith(fontSize: 20),
                        ),
                        Text(
                          'total baaki',
                          style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasOverdue || ar.dueThisWeekCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (hasOverdue)
                      _AlertChip(
                        label: '${ar.overdueCount} overdue',
                        color: KColors.error,
                      ),
                    if (hasOverdue && ar.dueThisWeekCount > 0)
                      const SizedBox(width: 8),
                    if (ar.dueThisWeekCount > 0)
                      _AlertChip(
                        label: '${CurrencyFormatter.formatCompact(ar.dueThisWeek)} this week',
                        color: KColors.warning,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
