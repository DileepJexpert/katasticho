import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

/// Revenue trend bar chart using fl_chart.
/// Supports 7 / 30 / 90-day windows selectable via dropdown.
class SalesChartWidget extends ConsumerStatefulWidget {
  const SalesChartWidget({super.key});

  @override
  ConsumerState<SalesChartWidget> createState() => _SalesChartWidgetState();
}

class _SalesChartWidgetState extends ConsumerState<SalesChartWidget> {
  int _days = 30;
  int? _touchedIndex;

  static const _options = [
    (label: 'Last 7 days', days: 7),
    (label: 'Last 30 days', days: 30),
    (label: 'Last 90 days', days: 90),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(revenueTrendProvider(_days));
    final cs = Theme.of(context).colorScheme;

    return KCard(
      title: 'Revenue Trend',
      action: DropdownButton<int>(
        value: _days,
        underline: const SizedBox(),
        style: KTypography.labelMedium,
        items: _options
            .map((o) => DropdownMenuItem(
                value: o.days, child: Text(o.label)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _days = v);
        },
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (err, _) => SizedBox(
          height: 200,
          child: Center(
            child: Text('Failed to load chart',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.error)),
          ),
        ),
        data: (data) {
          if (data.trend.isEmpty || data.totalRevenue == 0) {
            return const SizedBox(
              height: 200,
              child: KEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No revenue yet',
                subtitle: 'Send your first invoice to see the trend.',
              ),
            );
          }
          return _Chart(
            data: data,
            days: _days,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
            cs: cs,
          );
        },
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final RevenueTrendData data;
  final int days;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;
  final ColorScheme cs;

  const _Chart({
    required this.data,
    required this.days,
    required this.touchedIndex,
    required this.onTouch,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = data.trend
        .map((p) => p.revenue)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final chartMaxY = maxY > 0 ? maxY * 1.25 : 100.0;

    // For 30+ days, group into buckets to avoid too many bars
    final points = _aggregate(data.trend, days);

    final barGroups = List.generate(points.length, (i) {
      final isTouched = touchedIndex == i;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: points[i].revenue,
            color: isTouched
                ? KColors.primary
                : KColors.primary.withValues(alpha: 0.65),
            width: _barWidth(points.length),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (touchedIndex != null && touchedIndex! < points.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  _labelFor(points[touchedIndex!].date, days),
                  style: KTypography.labelMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.formatIndian(
                      points[touchedIndex!].revenue),
                  style: KTypography.amountMedium,
                ),
              ],
            ),
          ),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
              barGroups: barGroups,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (v, _) => Text(
                      CurrencyFormatter.formatCompact(v),
                      style: KTypography.labelSmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _bottomInterval(points.length).toDouble(),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _shortLabel(points[idx].date, days),
                          style: KTypography.labelSmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => cs.surfaceContainerHigh,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    CurrencyFormatter.formatIndian(rod.toY),
                    KTypography.labelMedium,
                  ),
                ),
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent || event is FlPanEndEvent) {
                    onTouch(response?.spot?.touchedBarGroupIndex);
                  }
                },
              ),
            ),
          ),
        ),
        KSpacing.vGapSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Total: ', style: KTypography.labelMedium
                .copyWith(color: cs.onSurfaceVariant)),
            Text(CurrencyFormatter.formatIndian(data.totalRevenue),
                style: KTypography.amountSmall),
          ],
        ),
      ],
    );
  }

  List<DailyRevenue> _aggregate(List<DailyRevenue> raw, int days) {
    if (days <= 14) return raw;
    // Group into weekly buckets for 30-day, fortnightly for 90-day
    final bucketSize = days <= 30 ? 7 : 14;
    final result = <DailyRevenue>[];
    for (var i = 0; i < raw.length; i += bucketSize) {
      final slice = raw.skip(i).take(bucketSize).toList();
      final total = slice.fold<double>(0, (s, p) => s + p.revenue);
      result.add(DailyRevenue(date: slice.first.date, revenue: total));
    }
    return result;
  }

  double _barWidth(int count) {
    if (count <= 7) return 28;
    if (count <= 14) return 18;
    return 12;
  }

  int _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    return 3;
  }

  String _shortLabel(DateTime d, int days) {
    if (days <= 14) return DateFormat('dd').format(d);
    return DateFormat('dd/MM').format(d);
  }

  String _labelFor(DateTime d, int days) {
    if (days <= 14) return DateFormat('dd MMM').format(d);
    return 'Week of ${DateFormat('dd MMM').format(d)}';
  }
}
