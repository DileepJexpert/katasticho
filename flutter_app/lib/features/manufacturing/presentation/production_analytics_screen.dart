import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/manufacturing_repository.dart';

/// Read-only production analytics dashboard backed by three new
/// manufacturing report endpoints. One tabbed screen so the daily-driver
/// (production manager / floor head) has a single place to land.
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
            icon: const Icon(Icons.date_range),
            label: Text('${_iso(_from)} → ${_iso(_to)}',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Throughput'),
            Tab(text: 'Profitability'),
            Tab(text: 'Scrap rate'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No data in the selected range'));
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
    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.sm),
        child: Row(
          children: [
            Expanded(
                child: Text(row['date']?.toString() ?? '',
                    style: KTypography.bodySmall)),
            _Metric(label: 'Started', value: '${row['woStarted']}'),
            _Metric(label: 'Done', value: '${row['woCompleted']}'),
            _Metric(label: 'Qty', value: '${row['quantityProduced']}'),
            _Metric(label: 'Scrap', value: '${row['scrapQty']}'),
          ],
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
              child: Text('No completed work orders in the range'));
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final margin = r['marginPercent'];
            final loss = margin is num && margin < 0;
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              color: loss ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(loss
                    ? Icons.trending_down
                    : Icons.trending_up,
                    color: loss ? Colors.red : Colors.green),
                title: Text('${r['workOrderNumber']}'),
                subtitle: Text(
                  'Produced ${r['quantityProduced']} • '
                  'Revenue ₹${r['revenue']} • '
                  'Cost ₹${r['cost']}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${r['profit']}',
                        style: KTypography.titleMedium),
                    Text('$margin%',
                        style: KTypography.bodySmall),
                  ],
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (dash) {
        final byItem = (dash['byItem'] as List?) ?? [];
        final byReason = (dash['byReason'] as List?) ?? [];
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: [
                    _Metric(
                        label: 'Total scrap qty',
                        value: '${dash['totalScrapQty']}'),
                    const SizedBox(width: KSpacing.md),
                    _Metric(
                        label: 'Total scrap cost',
                        value: '₹${dash['totalScrapCost']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Text('By item (worst rate first)',
                style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.sm),
            ...byItem.map((r) => _ScrapItemRow(row: r as Map<String, dynamic>)),
            const SizedBox(height: KSpacing.md),
            Text('By reason (highest cost first)',
                style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.sm),
            ...byReason.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: ListTile(
                    title: Text('${r['reasonCode']}'),
                    subtitle: Text('Scrap qty: ${r['scrapQty']}'),
                    trailing: Text('₹${r['scrapCost']}'),
                  ),
                )),
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
    final rate = row['scrapRatePercent'];
    final red = rate is num && rate >= 5;
    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      color: red ? Colors.orange.shade50 : null,
      child: ListTile(
        title: Text('${row['itemName'] ?? row['itemId']}'),
        subtitle: Text(
            'Produced ${row['producedQty']} • Scrap ${row['scrapQty']}'),
        trailing: Text('$rate%',
            style: TextStyle(
                color: red ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold)),
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
        Text(value, style: KTypography.titleMedium),
        Text(label, style: KTypography.bodySmall),
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
