import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
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
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _targets = [];
  List<dynamic> _recentExecutions = [];

  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _load();
  }

  String _fmt(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.getDashboard(from: _fmt(_fromDate), to: _fmt(_toDate)),
        repo.listAllTargets(),
        repo.listExecutions(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _targets = results[1] as List<dynamic>;
        _recentExecutions = (results[2] as List<dynamic>).take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Field Sales Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date range row
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('From: ${_fmt(_fromDate)}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('To: ${_fmt(_toDate)}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Summary cards
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _kpiCard('Salespersons',
                          '${_dashboard['totalSalespersons'] ?? 0}', cs),
                      _kpiCard(
                          'Routes', '${_dashboard['totalRoutes'] ?? 0}', cs),
                      _kpiCard('Visits',
                          '${_dashboard['totalVisitsCompleted'] ?? 0}/${_dashboard['totalVisitsPlanned'] ?? 0}',
                          cs),
                      _kpiCard(
                          'Productive %',
                          '${((_dashboard['productiveVisitPct'] as num?)?.toStringAsFixed(1) ?? '0')}%',
                          cs),
                      _kpiCard(
                          'Orders',
                          CurrencyFormatter.formatCompact(
                              (_dashboard['totalOrdersValue'] as num?)
                                      ?.toDouble() ??
                                  0),
                          cs),
                      _kpiCard(
                          'Collections',
                          CurrencyFormatter.formatCompact(
                              (_dashboard['totalCollections'] as num?)
                                      ?.toDouble() ??
                                  0),
                          cs),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Targets section
                  Text('Salesman Targets',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_targets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No targets set')),
                    )
                  else
                    ..._targets.map((t) =>
                        _targetCard(t as Map<String, dynamic>, cs)),
                  const SizedBox(height: 24),

                  // Recent executions
                  Text('Recent Executions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_recentExecutions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No recent executions')),
                    )
                  else
                    ..._recentExecutions.map((e) =>
                        _executionRow(e as Map<String, dynamic>, cs)),
                ],
              ),
            ),
    );
  }

  Widget _kpiCard(String label, String value, ColorScheme cs) {
    return SizedBox(
      width: 110,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _targetCard(Map<String, dynamic> target, ColorScheme cs) {
    final targetValue = (target['targetValue'] as num?)?.toDouble() ?? 0;
    final achieved = (target['achievedValue'] as num?)?.toDouble() ?? 0;
    final pct = (target['achievementPct'] as num?)?.toDouble() ?? 0;
    final incentive = (target['incentiveAmount'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Chip(
                label: Text(target['targetType'] ?? '',
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Text(
                  '${target['periodStart'] ?? ''} - ${target['periodEnd'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: cs.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text('${CurrencyFormatter.formatIndian(achieved)} / ${CurrencyFormatter.formatIndian(targetValue)}',
                  style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text('${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pct >= 100 ? Colors.green : cs.primary)),
            ]),
            if (incentive > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'Incentive: ${CurrencyFormatter.formatIndian(incentive)}',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _executionRow(Map<String, dynamic> exec, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        title: Text(exec['executionDate']?.toString() ?? '',
            style: const TextStyle(fontSize: 13)),
        subtitle: Text(
            '${exec['completedVisits'] ?? 0}/${exec['plannedVisits'] ?? 0} visits  •  ${CurrencyFormatter.formatIndian((exec['totalOrdersValue'] as num?)?.toDouble() ?? 0)}',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        trailing: Chip(
          label: Text(exec['status'] ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: exec['status'] == 'COMPLETED'
              ? Colors.green
              : exec['status'] == 'IN_PROGRESS'
                  ? Colors.orange
                  : Colors.blue,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
