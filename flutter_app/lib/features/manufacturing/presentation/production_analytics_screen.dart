import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

/// Read-only production analytics dashboard backed by three manufacturing report endpoints.
class ProductionAnalyticsScreen extends ConsumerStatefulWidget {
  const ProductionAnalyticsScreen({super.key});

  @override
  ConsumerState<ProductionAnalyticsScreen> createState() =>
      _ProductionAnalyticsScreenState();
}

class _ProductionAnalyticsScreenState
    extends ConsumerState<ProductionAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Analytics'),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: Text('${_iso(_from)} → ${_iso(_to)}',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Throughput'),
            Tab(text: 'Profitability'),
            Tab(text: 'Scrap Rate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ThroughputTab(from: _iso(_from), to: _iso(_to)),
          _ProfitabilityTab(from: _iso(_from), to: _iso(_to)),
          _ScrapRateTab(from: _iso(_from), to: _iso(_to)),
        ],
      ),
    );
  }
}

class _ThroughputTab extends ConsumerWidget {
  final String from;
  final String to;
  const _ThroughputTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_throughputProvider((from, to)));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading throughput trends...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.timeline,
            title: 'No throughput data',
            subtitle: 'No production runs recorded in the selected date range.',
          );
        }
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            for (final r in rows) _ThroughputRow(row: r),
          ],
        );
      },
    );
  }
}

class _ThroughputRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ThroughputRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row['date']?.toString() ?? '',
                  style: KTypography.labelLarge,
                ),
              ),
              _Metric(label: 'Started', value: '${row['woStarted']}'),
              KSpacing.hGapMd,
              _Metric(label: 'Done', value: '${row['woCompleted']}'),
              KSpacing.hGapMd,
              _Metric(label: 'Produced', value: '${row['quantityProduced']}'),
              KSpacing.hGapMd,
              _Metric(label: 'Scrapped', value: '${row['scrapQty']}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfitabilityTab extends ConsumerWidget {
  final String from;
  final String to;
  const _ProfitabilityTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_profitabilityProvider((from, to)));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading work order margins...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.monetization_on_outlined,
            title: 'No completed work orders',
            subtitle: 'No work orders completed in the selected date range.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final margin = (r['marginPercent'] as num?)?.toDouble() ?? 0;
            final loss = margin < 0;
            final revenue = (r['revenue'] as num?)?.toDouble() ?? 0;
            final cost = (r['cost'] as num?)?.toDouble() ?? 0;
            final profit = (r['profit'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        loss ? Icons.trending_down : Icons.trending_up,
                        color: loss ? KColors.error : KColors.success,
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['workOrderNumber']?.toString() ?? 'WO',
                              style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            KSpacing.vGapXxs,
                            Row(
                              children: [
                                Text('Qty: ${r['quantityProduced']} · Rev: ', style: KTypography.bodySmall),
                                KMoney(revenue, size: KMoneySize.small),
                                Text(' · Cost: ', style: KTypography.bodySmall),
                                KMoney(cost, size: KMoneySize.small),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          KMoney(profit, size: KMoneySize.medium, style: TextStyle(fontWeight: FontWeight.w700, color: loss ? KColors.error : KColors.success)),
                          KSpacing.vGapXxs,
                          Text(
                            '${margin.toStringAsFixed(1)}%',
                            style: KTypography.bodySmall.copyWith(color: loss ? KColors.error : KColors.success, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScrapRateTab extends ConsumerWidget {
  final String from;
  final String to;
  const _ScrapRateTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_scrapProvider((from, to)));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading scrap analytics...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (dash) {
        final byItem = (dash['byItem'] as List?) ?? [];
        final byReason = (dash['byReason'] as List?) ?? [];
        final totalScrapCost = (dash['totalScrapCost'] as num?)?.toDouble() ?? 0;

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: [
                    _Metric(
                        label: 'Total Scrap Qty',
                        value: '${dash['totalScrapQty'] ?? 0}'),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Scrap Cost', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                        KSpacing.vGapXxs,
                        KMoney(totalScrapCost, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.error)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,
            Text('By Item (Worst Rate First)', style: KTypography.titleSmall),
            KSpacing.vGapSm,
            if (byItem.isEmpty)
              const KEmptyState(icon: Icons.check_circle_outline, title: 'No scrap recorded', subtitle: 'Zero scrap reported by item.')
            else
              ...byItem.map((r) => _ScrapItemRow(row: r as Map<String, dynamic>)),
            KSpacing.vGapMd,
            Text('By Reason Code', style: KTypography.titleSmall),
            KSpacing.vGapSm,
            if (byReason.isEmpty)
              const KEmptyState(icon: Icons.check_circle_outline, title: 'No scrap reasons', subtitle: 'Zero scrap reason entries recorded.')
            else
              ...byReason.map((r) {
                final cost = (r['scrapCost'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r['reasonCode']}', style: KTypography.labelLarge),
                                KSpacing.vGapXxs,
                                Text('Scrap Qty: ${r['scrapQty']}', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                              ],
                            ),
                          ),
                          KMoney(cost, size: KMoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _ScrapItemRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ScrapItemRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final rate = (row['scrapRatePercent'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['itemName'] ?? row['itemId']}', style: KTypography.labelLarge),
                    KSpacing.vGapXxs,
                    Text('Produced: ${row['producedQty']} • Scrapped: ${row['scrapQty']}', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ),
              KStatusChip(
                status: '${rate.toStringAsFixed(1)}% Scrap',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: KTypography.h4),
        Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
      ],
    );
  }
}

final _throughputProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String)>((ref, range) {
  return ref
      .watch(manufacturingRepositoryProvider)
      .getProductionTrends(fromDate: range.$1, toDate: range.$2);
});

final _profitabilityProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String)>((ref, range) {
  return ref
      .watch(manufacturingRepositoryProvider)
      .getWorkOrderProfitability(fromDate: range.$1, toDate: range.$2);
});

final _scrapProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String, String)>((ref, range) {
  return ref
      .watch(manufacturingRepositoryProvider)
      .getScrapRateDashboard(fromDate: range.$1, toDate: range.$2);
});
