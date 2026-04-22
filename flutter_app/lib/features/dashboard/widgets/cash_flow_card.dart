import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class CashFlowCard extends ConsumerWidget {
  const CashFlowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashFlowProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Cash Flow',
        child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Cash Flow',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (data) {
        final cs = Theme.of(context).colorScheme;
        final isPositive = data.netCashFlow >= 0;

        return KCard(
          title: 'Cash Flow',
          subtitle: 'Month to date',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _FlowItem(
                    label: 'Cash In',
                    value: data.cashIn,
                    icon: Icons.arrow_downward_rounded,
                    color: KColors.success,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _FlowItem(
                    label: 'Cash Out',
                    value: data.cashOut,
                    icon: Icons.arrow_upward_rounded,
                    color: KColors.error,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPositive ? KColors.success : KColors.error).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isPositive ? KColors.success : KColors.error).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 18,
                      color: isPositive ? KColors.success : KColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Net: ${CurrencyFormatter.formatIndian(data.netCashFlow)}',
                      style: KTypography.amountMedium.copyWith(
                        color: isPositive ? KColors.success : KColors.error,
                        fontSize: 16,
                      ),
                    ),
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

class _FlowItem extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _FlowItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatCompact(value),
            style: KTypography.amountSmall.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
