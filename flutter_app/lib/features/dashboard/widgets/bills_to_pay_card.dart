import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class BillsToPayCard extends ConsumerWidget {
  const BillsToPayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(apSummaryProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Bills to Pay',
        child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Bills to Pay',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (ap) {
        final cs = Theme.of(context).colorScheme;
        final hasOverdue = ap.overdueCount > 0;

        return KCard(
          title: 'Bills to Pay',
          subtitle: 'Vendor payments pending',
          action: TextButton(
            onPressed: () => context.go('/bills'),
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
                      color: KColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_outlined,
                        color: KColors.error, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.formatIndian(ap.totalOutstanding),
                          style: KTypography.amountMedium.copyWith(fontSize: 20),
                        ),
                        Text(
                          'total pending',
                          style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasOverdue || ap.dueThisWeekCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (hasOverdue)
                      _AlertChip(
                        label: '${ap.overdueCount} overdue',
                        color: KColors.error,
                      ),
                    if (hasOverdue && ap.dueThisWeekCount > 0)
                      const SizedBox(width: 8),
                    if (ap.dueThisWeekCount > 0)
                      _AlertChip(
                        label: '${CurrencyFormatter.formatCompact(ap.dueThisWeek)} due this week',
                        color: KColors.warning,
                      ),
                  ],
                ),
              ],
              if (!hasOverdue && ap.dueThisWeekCount == 0 && ap.totalOutstanding == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: KColors.success),
                      const SizedBox(width: 6),
                      Text('All clear!', style: KTypography.labelMedium.copyWith(color: KColors.success)),
                    ],
                  ),
                ),
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
