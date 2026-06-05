import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/field_sales_repository.dart';

class DayCloseScreen extends ConsumerStatefulWidget {
  const DayCloseScreen({super.key});

  @override
  ConsumerState<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends ConsumerState<DayCloseScreen> {
  bool _isLoading = true;
  List<dynamic> _executions = [];
  Map<String, dynamic>? _dayClose;
  String? _activeExecutionId;

  final _closingCashCtrl = TextEditingController();
  final _cashDepositedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closingCashCtrl.dispose();
    _cashDepositedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final execs = await repo.listExecutions();
      if (!mounted) return;
      setState(() {
        _executions =
            execs.where((e) => e['status'] == 'COMPLETED').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _initiateDayClose(String executionId) async {
    try {
      final dc = await ref
          .read(fieldSalesRepositoryProvider)
          .initiateDayClose(executionId);
      if (!mounted) return;
      setState(() {
        _dayClose = dc;
        _activeExecutionId = executionId;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submitDayClose() async {
    if (_dayClose == null) return;
    try {
      final dc = await ref.read(fieldSalesRepositoryProvider).submitDayClose(
        _dayClose!['id'].toString(),
        {
          'closingCash': double.tryParse(_closingCashCtrl.text) ?? 0,
          'cashDeposited': double.tryParse(_cashDepositedCtrl.text) ?? 0,
          'notes': _notesCtrl.text,
        },
      );
      if (!mounted) return;
      setState(() => _dayClose = dc);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Day close submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveDayClose() async {
    if (_dayClose == null) return;
    try {
      final dc = await ref
          .read(fieldSalesRepositoryProvider)
          .approveDayClose(_dayClose!['id'].toString());
      if (!mounted) return;
      setState(() => _dayClose = dc);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Day close approved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectDayClose() async {
    if (_dayClose == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Day Close'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Reject')),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      final dc = await ref
          .read(fieldSalesRepositoryProvider)
          .rejectDayClose(_dayClose!['id'].toString(), {'reason': reason});
      if (!mounted) return;
      setState(() => _dayClose = dc);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Day close rejected')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Day Close')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dayClose != null
              ? _buildDayCloseForm()
              : _buildExecutionList(),
    );
  }

  Widget _buildExecutionList() {
    if (_executions.isEmpty) {
      return const Center(child: Text('No completed routes for day close'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _executions.length,
        itemBuilder: (ctx, i) {
          final e = _executions[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('Route ${e['routeId']?.toString().substring(0, 8) ?? ''}'),
              subtitle: Text(
                  '${e['executionDate']}  •  ${e['completedVisits']}/${e['plannedVisits']} visits  •  ${CurrencyFormatter.formatIndian((e['totalOrdersValue'] as num?)?.toDouble() ?? 0)}'),
              trailing: FilledButton.tonal(
                onPressed: () => _initiateDayClose(e['id'].toString()),
                child: const Text('Day Close'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCloseForm() {
    final dc = _dayClose!;
    final status = dc['status'] as String? ?? 'PENDING';
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Day Close', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Chip(
            label: Text(status),
            backgroundColor: status == 'APPROVED'
                ? Colors.green.shade100
                : status == 'REJECTED'
                    ? Colors.red.shade100
                    : Colors.orange.shade100,
          ),
        ]),
        const SizedBox(height: 16),
        // Cash Section
        Text('Cash Reconciliation',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _readOnlyField(
            'Opening Cash', dc['openingCash']?.toString() ?? '0'),
        _readOnlyField(
            'Cash Collections', dc['cashCollections']?.toString() ?? '0'),
        TextField(
          controller: _closingCashCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Closing Cash', border: OutlineInputBorder()),
          enabled: status == 'PENDING',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cashDepositedCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Cash Deposited', border: OutlineInputBorder()),
          enabled: status == 'PENDING',
        ),
        _readOnlyField(
            'Cash Variance', dc['cashVariance']?.toString() ?? '0'),
        const SizedBox(height: 16),
        // Visit Summary
        Text('Visit Summary',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(children: [
          _metricChip('Planned', dc['visitsPlanned']?.toString() ?? '0', cs),
          _metricChip(
              'Completed', dc['visitsCompleted']?.toString() ?? '0', cs),
          _metricChip(
              'Productive', dc['visitsProductive']?.toString() ?? '0', cs),
        ]),
        const SizedBox(height: 16),
        // Financial Summary
        Text('Financial Summary',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _readOnlyField('Total Orders',
            CurrencyFormatter.formatIndian(
                (dc['totalOrdersValue'] as num?)?.toDouble() ?? 0)),
        _readOnlyField('Total Collections',
            CurrencyFormatter.formatIndian(
                (dc['totalCollections'] as num?)?.toDouble() ?? 0)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Notes', border: OutlineInputBorder()),
          enabled: status == 'PENDING',
        ),
        const SizedBox(height: 24),
        if (status == 'PENDING')
          FilledButton(
            onPressed: _submitDayClose,
            child: const Text('Submit Day Close'),
          ),
        if (status == 'SUBMITTED') ...[
          FilledButton(
            onPressed: _approveDayClose,
            child: const Text('Approve'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _rejectDayClose,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _dayClose = null;
            _activeExecutionId = null;
          }),
          child: const Text('Back to list'),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value),
      ),
    );
  }

  Widget _metricChip(String label, String value, ColorScheme cs) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
