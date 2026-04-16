import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

/// Cash position overview — shows AR receivables alongside AP payables
/// and highlights bills due within the next 7 days.
class CashPositionWidget extends ConsumerWidget {
  const CashPositionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(todaySalesProvider);
    final apAsync = ref.watch(apSummaryProvider);

    return KCard(
      title: 'Cash Position',
      child: Column(
        children: [
          // AR row
          salesAsync.when(
            loading: () => const _PositionRow(
              label: 'Receivables (AR)',
              value: '...',
              icon: Icons.arrow_downward,
              color: KColors.success,
            ),
            error: (_, __) => const _PositionRow(
              label: 'Receivables (AR)',
              value: '—',
              icon: Icons.arrow_downward,
              color: KColors.success,
            ),
            data: (sales) => _PositionRow(
              label: 'Receivables (AR)',
              value: CurrencyFormatter.formatIndian(sales.cashCollected),
              icon: Icons.arrow_downward,
              color: KColors.success,
            ),
          ),
          const Divider(height: 16),

          // AP row
          apAsync.when(
            loading: () => const _PositionRow(
              label: 'Payables (AP)',
              value: '...',
              icon: Icons.arrow_upward,
              color: KColors.error,
            ),
            error: (_, __) => const _PositionRow(
              label: 'Payables (AP)',
              value: '—',
              icon: Icons.arrow_upward,
              color: KColors.error,
            ),
            data: (ap) => _PositionRow(
              label: 'Payables (AP)',
              value: CurrencyFormatter.formatIndian(ap.totalOutstanding),
              icon: Icons.arrow_upward,
              color: KColors.error,
            ),
          ),
          const Divider(height: 16),

          // AP due this week
          apAsync.when(
            loading: () => const _PositionRow(
              label: 'AP Due This Week',
              value: '...',
              icon: Icons.schedule,
              color: KColors.warning,
            ),
            error: (_, __) => const _PositionRow(
              label: 'AP Due This Week',
              value: '—',
              icon: Icons.schedule,
              color: KColors.warning,
            ),
            data: (ap) => _PositionRow(
              label: 'AP Due This Week',
              value: CurrencyFormatter.formatIndian(ap.dueThisWeek),
              icon: Icons.schedule,
              color: KColors.warning,
              badge: ap.dueThisWeekCount > 0
                  ? '${ap.dueThisWeekCount} bills'
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;

  const _PositionRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: KSpacing.borderRadiusMd,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        KSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: KTypography.bodySmall),
              if (badge != null)
                Text(
                  badge!,
                  style: KTypography.labelSmall.copyWith(
                    color: color,
                  ),
                ),
            ],
          ),
        ),
        Text(value, style: KTypography.amountSmall),
      ],
    );
  }
}
