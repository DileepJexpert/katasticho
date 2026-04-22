import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class AajKaHisaabCard extends ConsumerWidget {
  const AajKaHisaabCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailySummaryProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Aaj Ka Hisaab',
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Aaj Ka Hisaab',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (data) {
        final t = data.today;
        final cs = Theme.of(context).colorScheme;

        return KCard(
          title: 'Aaj Ka Hisaab',
          subtitle: "Today's Summary",
          child: Column(
            children: [
              _HeroRow(
                label: 'Aaj Ki Kamai',
                value: t.earning,
                color: t.earning >= 0 ? KColors.success : KColors.error,
                icon: t.earning >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniStat(
                    label: 'Bechaan (Sale)',
                    value: CurrencyFormatter.formatCompact(t.totalSale),
                    icon: Icons.point_of_sale_rounded,
                    color: cs.primary,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(
                    label: 'Lagat (Cost)',
                    value: CurrencyFormatter.formatCompact(t.totalCost),
                    icon: Icons.shopping_bag_outlined,
                    color: KColors.warning,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _MiniStat(
                    label: 'Naqad/UPI',
                    value: CurrencyFormatter.formatCompact(t.cashUpiIn),
                    icon: Icons.payments_outlined,
                    color: KColors.success,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(
                    label: 'Udhari (Credit)',
                    value: CurrencyFormatter.formatCompact(t.creditSale),
                    icon: Icons.credit_card_outlined,
                    color: KColors.error,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${t.billCount} bills today',
                      style: KTypography.labelMedium.copyWith(color: cs.onSurfaceVariant),
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

class _HeroRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _HeroRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatIndian(value),
                  style: KTypography.h1.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
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
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: KTypography.amountSmall.copyWith(color: cs.onSurface)),
                Text(label, style: KTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant, fontSize: 10,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
