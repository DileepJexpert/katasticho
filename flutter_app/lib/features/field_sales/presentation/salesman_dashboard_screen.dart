import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class SalesmanDashboardScreen extends ConsumerStatefulWidget {
  const SalesmanDashboardScreen({super.key});

  @override
  ConsumerState<SalesmanDashboardScreen> createState() =>
      _SalesmanDashboardScreenState();
}

class _SalesmanDashboardScreenState
    extends ConsumerState<SalesmanDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _targets = [];
  List<Map<String, dynamic>> _recentExecutions = [];

  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final fromStr = _fromDate.toIso8601String().split('T')[0];
      final toStr = _toDate.toIso8601String().split('T')[0];

      final results = await Future.wait([
        repo.getDashboard(from: fromStr, to: toStr),
        repo.listTargets(),
        repo.listExecutions(),
      ]);

      if (mounted) {
        setState(() {
          _dashboard = results[0] as Map<String, dynamic>;
          _targets = (results[1] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          _recentExecutions = (results[2] as List)
              .whereType<Map<String, dynamic>>()
              .take(10)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2024),
      lastDate: _toDate,
    );
    if (picked != null && mounted) {
      setState(() => _fromDate = picked);
      _loadData();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _toDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Field Sales Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final db = _dashboard ?? {};
    final totalRoutes = (db['totalRoutes'] as num?)?.toInt() ?? 0;
    final totalVisits = (db['totalVisits'] as num?)?.toInt() ?? 0;
    final productivePercent =
        (db['productivePercent'] as num?)?.toDouble() ?? 0;
    final avgOrderValue =
        (db['avgOrderValue'] as num?)?.toDouble() ?? 0;
    final totalOrders =
        (db['totalOrders'] as num?)?.toDouble() ??
            (db['totalOrdersValue'] as num?)?.toDouble() ??
            0;
    final totalCollections =
        (db['totalCollections'] as num?)?.toDouble() ?? 0;

    final fromStr = _fromDate.toIso8601String().split('T')[0];
    final toStr = _toDate.toIso8601String().split('T')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Sales Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // -- Date Range Picker Row --
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(fromStr, style: KTypography.bodySmall),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickToDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(toStr, style: KTypography.bodySmall),
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,

            // -- Summary Cards --
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                _DashboardMetric(
                  label: 'Total Routes',
                  value: '$totalRoutes',
                  icon: Icons.route_outlined,
                  color: KColors.primary,
                ),
                _DashboardMetric(
                  label: 'Total Visits',
                  value: '$totalVisits',
                  icon: Icons.store_outlined,
                  color: KColors.info,
                ),
                _DashboardMetric(
                  label: 'Productive %',
                  value: '${productivePercent.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: KColors.success,
                ),
                _DashboardMetric(
                  label: 'Avg Order Value',
                  value: CurrencyFormatter.formatIndian(avgOrderValue),
                  icon: Icons.receipt_long_outlined,
                  color: KColors.warning,
                ),
                _DashboardMetric(
                  label: 'Total Orders',
                  value: CurrencyFormatter.formatIndian(totalOrders),
                  icon: Icons.shopping_cart_outlined,
                  color: KColors.primary,
                ),
                _DashboardMetric(
                  label: 'Total Collections',
                  value: CurrencyFormatter.formatIndian(totalCollections),
                  icon: Icons.payments_outlined,
                  color: KColors.success,
                ),
              ],
            ),
            KSpacing.vGapLg,

            // -- Salesman Targets Section --
            Text('Salesman Targets', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            if (_targets.isEmpty)
              const Center(child: Text('No targets found'))
            else
              ..._targets.map((target) {
                final targetType = target['targetType']?.toString() ??
                    target['type']?.toString() ??
                    '--';
                final period = target['period']?.toString() ?? '--';
                final targetValue =
                    (target['targetValue'] as num?)?.toDouble() ??
                        (target['target'] as num?)?.toDouble() ??
                        0;
                final achieved =
                    (target['achieved'] as num?)?.toDouble() ??
                        (target['achievedValue'] as num?)?.toDouble() ??
                        0;
                final percentage = targetValue > 0
                    ? (achieved / targetValue).clamp(0.0, 1.0)
                    : 0.0;
                final percentText = targetValue > 0
                    ? '${(achieved / targetValue * 100).toStringAsFixed(1)}%'
                    : '0%';
                final incentive =
                    (target['incentiveAmount'] as num?)?.toDouble() ??
                        (target['incentive'] as num?)?.toDouble();

                Color progressColor;
                if (percentage >= 0.9) {
                  progressColor = KColors.success;
                } else if (percentage >= 0.5) {
                  progressColor = KColors.warning;
                } else {
                  progressColor = KColors.error;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: KColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(targetType,
                                  style: KTypography.bodySmall.copyWith(
                                      color: KColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                            KSpacing.hGapSm,
                            Text(period,
                                style: KTypography.bodySmall.copyWith(
                                    color: KColors.textSecondary)),
                            const Spacer(),
                            Text(percentText,
                                style: KTypography.labelMedium
                                    .copyWith(color: progressColor)),
                          ],
                        ),
                        KSpacing.vGapSm,
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${CurrencyFormatter.formatIndian(achieved)} / ${CurrencyFormatter.formatIndian(targetValue)}',
                                style: KTypography.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        KSpacing.vGapXs,
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor:
                                progressColor.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 8,
                          ),
                        ),
                        if (incentive != null && incentive > 0) ...[
                          KSpacing.vGapXs,
                          Text(
                            'Incentive: ${CurrencyFormatter.formatIndian(incentive)}',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.success),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            KSpacing.vGapLg,

            // -- Recent Executions Section --
            Text('Recent Executions', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            if (_recentExecutions.isEmpty)
              const Center(child: Text('No recent executions'))
            else
              ..._recentExecutions.map((exec) {
                final execDate = exec['date']?.toString() ?? '--';
                final routeName = exec['routeName']?.toString() ??
                    exec['routeId']?.toString() ??
                    '--';
                final totalV =
                    (exec['totalVisits'] as num?)?.toInt() ?? 0;
                final completedV =
                    (exec['completedVisits'] as num?)?.toInt() ?? 0;
                final ordersVal =
                    (exec['ordersValue'] as num?)?.toDouble() ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.xs),
                  child: KCard(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(routeName,
                                  style: KTypography.bodyMedium,
                                  overflow: TextOverflow.ellipsis),
                              Text(execDate,
                                  style: KTypography.bodySmall.copyWith(
                                      color: KColors.textSecondary)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text('$completedV/$totalV',
                              style: KTypography.bodySmall,
                              textAlign: TextAlign.center),
                        ),
                        Expanded(
                          child: Text(
                              CurrencyFormatter.formatIndian(ordersVal),
                              style: KTypography.labelMedium,
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: KTypography.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}
