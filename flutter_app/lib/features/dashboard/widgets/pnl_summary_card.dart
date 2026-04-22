import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class PnlSummaryCard extends ConsumerWidget {
  const PnlSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profitLossProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Profit & Loss',
        child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Profit & Loss',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (data) {
        final cs = Theme.of(context).colorScheme;
        final isProfit = data.netProfit >= 0;

        return KCard(
          title: 'Profit & Loss',
          subtitle: 'Current month',
          action: TextButton(
            onPressed: () => context.go('/reports/profit-loss'),
            child: const Text('Full Report'),
          ),
          child: Column(
            children: [
              _PnlRow(
                label: 'Revenue',
                value: data.totalRevenue,
                color: KColors.success,
                icon: Icons.trending_up_rounded,
              ),
              const SizedBox(height: 8),
              _PnlRow(
                label: 'Expenses',
                value: data.totalExpenses,
                color: KColors.error,
                icon: Icons.trending_down_rounded,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isProfit ? KColors.success : KColors.error).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isProfit ? 'Net Profit' : 'Net Loss',
                      style: KTypography.labelMedium.copyWith(
                        color: isProfit ? KColors.success : KColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(data.netProfit.abs()),
                      style: KTypography.amountMedium.copyWith(
                        color: isProfit ? KColors.success : KColors.error,
                        fontSize: 18,
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

class _PnlRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _PnlRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: KTypography.labelMedium.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          CurrencyFormatter.formatCompact(value),
          style: KTypography.amountSmall.copyWith(color: cs.onSurface),
        ),
      ],
    );
  }
}
