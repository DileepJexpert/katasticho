import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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
        appBar: AppBar(title: const Text('Field Sales & Distribution Analytics')),
        body: const Center(child: KLoading()),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= KSpacing.tabletBreakpoint;
                final metrics = [
                  _DashboardMetricData(
                    label: 'Total Routes',
                    valueWidget: Text('$totalRoutes', style: KTypography.h4.copyWith(color: KColors.primary)),
                    icon: Icons.route_outlined,
                    color: KColors.primary,
                  ),
                  _DashboardMetricData(
                    label: 'Total Visits',
                    valueWidget: Text('$totalVisits', style: KTypography.h4.copyWith(color: KColors.info)),
                    icon: Icons.store_outlined,
                    color: KColors.info,
                  ),
                  _DashboardMetricData(
                    label: 'Productive %',
                    valueWidget: Text('${productivePercent.toStringAsFixed(1)}%', style: KTypography.h4.copyWith(color: KColors.success)),
                    icon: Icons.trending_up,
                    color: KColors.success,
                  ),
                  _DashboardMetricData(
                    label: 'Avg Order Value',
                    valueWidget: KMoney(avgOrderValue, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700)),
                    icon: Icons.receipt_long_outlined,
                    color: KColors.warning,
                  ),
                  _DashboardMetricData(
                    label: 'Total Orders',
                    valueWidget: KMoney(totalOrders, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700)),
                    icon: Icons.shopping_cart_outlined,
                    color: KColors.primary,
                  ),
                  _DashboardMetricData(
                    label: 'Total Collections',
                    valueWidget: KMoney(totalCollections, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.success)),
                    icon: Icons.payments_outlined,
                    color: KColors.success,
                  ),
                ];

                if (isWide) {
                  return Wrap(
                    spacing: KSpacing.sm,
                    runSpacing: KSpacing.sm,
                    children: metrics.map((m) {
                      return SizedBox(
                        width: (constraints.maxWidth - 2 * KSpacing.sm) / 3,
                        child: KCard(
                          statusAccent: m.color,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(m.icon, size: 16, color: m.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(m.label, style: KTypography.labelSmall, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              m.valueWidget,
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }

                return Column(
                  children: metrics.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.xs),
                      child: KCard(
                        statusAccent: m.color,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(m.icon, size: 16, color: m.color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.label, style: KTypography.labelMedium)),
                            m.valueWidget,
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            KSpacing.vGapLg,

            // -- Salesman Targets Section --
            Text('Salesman Targets & Quotas', style: KTypography.titleLarge),
            KSpacing.vGapSm,
            if (_targets.isEmpty)
              const KEmptyState(
                icon: Icons.track_changes_outlined,
                title: 'No sales quotas assigned',
                subtitle: 'Targets and incentive structures configured for field reps will display here.',
              )
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
                    statusAccent: progressColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            KStatusChip(
                              status: 'TARGET',
                              label: targetType,
                            ),
                            KSpacing.hGapSm,
                            Text(
                              period,
                              style: KTypography.mono(
                                fontSize: 12,
                                color: KColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              percentText,
                              style: KTypography.mono(
                                fontSize: 13,
                                color: progressColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        KSpacing.vGapSm,
                        Row(
                          children: [
                            Text('Achieved: ', style: KTypography.bodySmall),
                            KMoney(achieved, size: KMoneySize.small),
                            Text(' / Target: ', style: KTypography.bodySmall),
                            KMoney(targetValue, size: KMoneySize.small),
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
                            minHeight: 6,
                          ),
                        ),
                        if (incentive != null && incentive > 0) ...[
                          KSpacing.vGapXs,
                          Row(
                            children: [
                              Text('Incentive: ', style: KTypography.bodySmall),
                              KMoney(
                                incentive,
                                size: KMoneySize.small,
                                style: const TextStyle(color: KColors.success, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            KSpacing.vGapLg,

            // -- Recent Executions Section --
            Text('Recent Route Executions', style: KTypography.titleLarge),
            KSpacing.vGapSm,
            if (_recentExecutions.isEmpty)
              const KEmptyState(
                icon: Icons.history_outlined,
                title: 'No recent route activity',
                subtitle: 'Daily salesperson check-ins and order logs will appear here once trips commence.',
              )
            else
              KDataTable(
                columns: const [
                  KTableColumn(label: 'Route'),
                  KTableColumn(label: 'Date'),
                  KTableColumn(label: 'Visits'),
                  KTableColumn(label: 'Orders Value', numeric: true),
                ],
                rows: _recentExecutions.map((exec) {
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

                  return [
                    Text(routeName, style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    Text(execDate, style: KTypography.bodySmall),
                    Text('$completedV / $totalV', style: KTypography.bodySmall),
                    KMoney(ordersVal, size: KMoneySize.small),
                  ];
                }).toList(),
              ),
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricData {
  final String label;
  final Widget valueWidget;
  final IconData icon;
  final Color color;

  const _DashboardMetricData({
    required this.label,
    required this.valueWidget,
    required this.icon,
    required this.color,
  });
}
