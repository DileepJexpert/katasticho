import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

class WeekTrendCard extends ConsumerWidget {
  const WeekTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailySummaryProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Last 7 Din',
        child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Last 7 Din',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (data) {
        final cs = Theme.of(context).colorScheme;
        final week = data.thisWeek;

        return KCard(
          title: 'Last 7 Din',
          subtitle: 'Weekly Trend',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _WeekStat(
                      label: 'Sale',
                      value: CurrencyFormatter.formatCompact(week.totalSale),
                      pct: week.vsLastWeekSalePct,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WeekStat(
                      label: 'Earning',
                      value: CurrencyFormatter.formatCompact(week.totalEarning),
                      pct: week.vsLastWeekEarningPct,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 100,
                child: _MiniBarChart(rows: data.daily),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String label;
  final String value;
  final double pct;

  const _WeekStat({required this.label, required this.value, required this.pct});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUp = pct >= 0;
    final pctColor = isUp ? KColors.success : KColors.error;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: KTypography.amountMedium),
          if (pct != 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 12,
                  color: pctColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '${pct.abs().toStringAsFixed(1)}% vs last week',
                  style: TextStyle(fontSize: 10, color: pctColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<DailySummaryRow> rows;
  const _MiniBarChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final maxSale = rows.map((r) => r.sale).fold<double>(0, (m, v) => v > m ? v : m);
    final barMax = maxSale > 0 ? maxSale : 1.0;

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: (rows[i].sale / barMax).clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: rows[i].earning >= 0
                            ? cs.primary.withValues(alpha: 0.7)
                            : KColors.error.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dayLabel(rows[i].date),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }
}
