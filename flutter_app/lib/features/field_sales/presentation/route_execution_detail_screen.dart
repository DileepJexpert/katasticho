import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/field_sales_repository.dart';

class RouteExecutionDetailScreen extends ConsumerStatefulWidget {
  final String executionId;
  const RouteExecutionDetailScreen({super.key, required this.executionId});

  @override
  ConsumerState<RouteExecutionDetailScreen> createState() =>
      _RouteExecutionDetailScreenState();
}

class _RouteExecutionDetailScreenState
    extends ConsumerState<RouteExecutionDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _execution = {};
  List<dynamic> _visits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.getExecution(widget.executionId),
        repo.getVisits(widget.executionId),
      ]);
      if (!mounted) return;
      setState(() {
        _execution = results[0] as Map<String, dynamic>;
        _visits = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color _statusColor(String status) => switch (status) {
        'PLANNED' => Colors.blue,
        'IN_PROGRESS' => Colors.orange,
        'COMPLETED' => KColors.success,
        'SKIPPED' => KColors.error,
        'NO_ORDER' => Colors.grey,
        _ => Colors.grey,
      };

  Future<void> _checkIn(String visitId) async {
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .checkIn(visitId, {'latitude': 0.0, 'longitude': 0.0});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Checked in')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _checkOut(String visitId) async {
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .checkOut(visitId, {'latitude': 0.0, 'longitude': 0.0});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Checked out')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _skipVisit(String visitId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Skip Visit'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Skip')),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .skipVisit(visitId, {'skipReason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visit skipped')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _recordOrder(String visitId) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Order'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Order Value'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await ref.read(fieldSalesRepositoryProvider).recordVisitOrder(
          visitId, {'orderValue': double.tryParse(value) ?? 0});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Order recorded')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _recordCollection(String visitId) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Collection'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await ref.read(fieldSalesRepositoryProvider).recordVisitCollection(
          visitId, {'collectionAmount': double.tryParse(value) ?? 0});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Collection recorded')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _completeRoute() async {
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .completeRoute(widget.executionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Route completed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _execution['status'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading
            ? 'Route Execution'
            : 'Route ${_execution['executionDate'] ?? ''}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status chip
                  Row(children: [
                    Chip(
                      label: Text(status,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      backgroundColor: _statusColor(status),
                    ),
                    const Spacer(),
                    Text('Date: ${_execution['executionDate'] ?? ''}'),
                  ]),
                  const SizedBox(height: 16),
                  // Summary cards
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _summaryCard('Planned',
                          '${_execution['plannedVisits'] ?? 0}', cs),
                      _summaryCard('Completed',
                          '${_execution['completedVisits'] ?? 0}', cs),
                      _summaryCard('Skipped',
                          '${_execution['skippedVisits'] ?? 0}', cs),
                      _summaryCard(
                          'Orders',
                          CurrencyFormatter.formatIndian(
                              (_execution['totalOrdersValue'] as num?)
                                      ?.toDouble() ??
                                  0),
                          cs),
                      _summaryCard(
                          'Collections',
                          CurrencyFormatter.formatIndian(
                              (_execution['totalCollections'] as num?)
                                      ?.toDouble() ??
                                  0),
                          cs),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Visits',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_visits.isEmpty)
                    const Center(child: Text('No visits'))
                  else
                    ..._visits.map((v) => _visitCard(v as Map<String, dynamic>)),
                ],
              ),
            ),
      bottomNavigationBar: !_isLoading && status == 'IN_PROGRESS'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _completeRoute,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Route'),
                ),
              ),
            )
          : !_isLoading && status == 'COMPLETED'
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/field-sales/day-close'),
                      icon: const Icon(Icons.nightlight),
                      label: const Text('Day Close'),
                    ),
                  ),
                )
              : null,
    );
  }

  Widget _summaryCard(String label, String value, ColorScheme cs) {
    return SizedBox(
      width: 110,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visitCard(Map<String, dynamic> visit) {
    final vStatus = visit['status'] as String? ?? 'PLANNED';
    final id = visit['id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${visit['sequenceNumber'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Customer: ${visit['contactId'] ?? ''}',
                      overflow: TextOverflow.ellipsis)),
              Chip(
                label: Text(vStatus,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: _statusColor(vStatus),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (vStatus == 'COMPLETED') ...[
              const SizedBox(height: 4),
              Text(
                  'Order: ${CurrencyFormatter.formatIndian((visit['orderValue'] as num?)?.toDouble() ?? 0)}  |  Collection: ${CurrencyFormatter.formatIndian((visit['collectionAmount'] as num?)?.toDouble() ?? 0)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (vStatus == 'SKIPPED' && visit['skipReason'] != null)
              Text('Reason: ${visit['skipReason']}',
                  style:
                      const TextStyle(fontSize: 12, color: KColors.error)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (vStatus == 'PLANNED')
                FilledButton.tonal(
                    onPressed: () => _checkIn(id),
                    child: const Text('Check In')),
              if (vStatus == 'PLANNED')
                OutlinedButton(
                    onPressed: () => _skipVisit(id),
                    child: const Text('Skip')),
              if (vStatus == 'IN_PROGRESS')
                FilledButton.tonal(
                    onPressed: () => _checkOut(id),
                    child: const Text('Check Out')),
              if (vStatus == 'IN_PROGRESS' || vStatus == 'COMPLETED') ...[
                OutlinedButton(
                    onPressed: () => _recordOrder(id),
                    child: const Text('Order')),
                OutlinedButton(
                    onPressed: () => _recordCollection(id),
                    child: const Text('Collection')),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
