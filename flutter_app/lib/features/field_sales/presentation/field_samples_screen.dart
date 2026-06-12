import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../data/field_sales_repository.dart';

/// Sample / promo material register per field salesperson (any vertical),
/// plus the org's TA/DA allowance rate configuration.
class FieldSamplesScreen extends ConsumerStatefulWidget {
  const FieldSamplesScreen({super.key});

  @override
  ConsumerState<FieldSamplesScreen> createState() => _FieldSamplesScreenState();
}

class _FieldSamplesScreenState extends ConsumerState<FieldSamplesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  List<Map<String, dynamic>> _balance = [];
  List<Map<String, dynamic>> _transactions = [];

  final _taPerKmCtrl = TextEditingController();
  final _daPerDayCtrl = TextEditingController();
  String _allowanceMode = 'FLEXIBLE';

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _taPerKmCtrl.dispose();
    _daPerDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    try {
      final usersResp = await _dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
      final usersData =
          (usersResp.data?['data'] as List?) ?? (usersResp.data as List? ?? []);
      final settingsResp =
          await _dio.get<Map<String, dynamic>>(ApiConfig.orgSettings);
      final settings = (settingsResp.data ?? {}).cast<String, dynamic>();

      if (mounted) {
        setState(() {
          _users = usersData
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          _taPerKmCtrl.text =
              settings['field_sales.ta_per_km']?.toString() ?? '';
          _daPerDayCtrl.text =
              settings['field_sales.da_per_day']?.toString() ?? '';
          _allowanceMode =
              settings['field_sales.allowance_mode']?.toString() ?? 'FLEXIBLE';
        });
      }
    } catch (e) {
      _toast('Failed to load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalesperson(String userId) async {
    setState(() => _selectedUserId = userId);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.sampleBalance(userId),
        repo.sampleTransactions(userId),
      ]);
      if (mounted) {
        setState(() {
          _balance = results[0];
          _transactions = results[1];
        });
      }
    } catch (e) {
      _toast('Failed to load samples: $e');
    }
  }

  Future<void> _saveRates() async {
    try {
      await _dio.put<Map<String, dynamic>>(ApiConfig.orgSettings, data: {
        'field_sales.ta_per_km':
            _taPerKmCtrl.text.trim().isEmpty ? '0' : _taPerKmCtrl.text.trim(),
        'field_sales.da_per_day':
            _daPerDayCtrl.text.trim().isEmpty ? '0' : _daPerDayCtrl.text.trim(),
        'field_sales.allowance_mode': _allowanceMode,
      });
      _toast('Allowance rates saved');
    } catch (e) {
      _toast('Failed to save rates: $e');
    }
  }

  Future<void> _recordTxn({required bool isIssue}) async {
    if (_selectedUserId == null) return;
    final productCtl = TextEditingController();
    final qtyCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIssue ? 'Issue Samples' : 'Record Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: productCtl,
              decoration:
                  const InputDecoration(labelText: 'Product / material'),
            ),
            TextField(
              controller: qtyCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isIssue ? 'Issue' : 'Return')),
        ],
      ),
    );
    if (ok != true) return;

    final qty = int.tryParse(qtyCtl.text) ?? 0;
    if (productCtl.text.trim().isEmpty || qty <= 0) {
      _toast('Product and a positive quantity are required');
      return;
    }
    try {
      await ref.read(fieldSalesRepositoryProvider).recordSampleTxn(
            isIssue: isIssue,
            salespersonId: _selectedUserId!,
            productName: productCtl.text.trim(),
            quantity: qty,
            notes: notesCtl.text.trim(),
          );
      await _loadSalesperson(_selectedUserId!);
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Samples & Allowance')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TA/DA allowance rates',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Travel allowance uses the GPS distance recorded by '
                          'the field app. Daily allowance applies on days with '
                          'field movement. Set 0 to disable.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _allowanceMode,
                          decoration: const InputDecoration(
                            labelText: 'Distance claiming mode',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'FLEXIBLE',
                              child: Text(
                                  'Flexible — GPS km prefilled, salesperson may adjust'),
                            ),
                            DropdownMenuItem(
                              value: 'GPS',
                              child: Text(
                                  'GPS strict — claim exactly the tracked distance'),
                            ),
                            DropdownMenuItem(
                              value: 'MANUAL',
                              child: Text(
                                  'Manual — salesperson enters km themselves'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _allowanceMode = v ?? 'FLEXIBLE'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _taPerKmCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'TA per km (₹)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _daPerDayCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'DA per day (₹)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _saveRates,
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Sample / promo stock register',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedUserId,
                  decoration:
                      const InputDecoration(labelText: 'Salesperson'),
                  items: _users
                      .map((u) => DropdownMenuItem(
                            value: u['id']?.toString(),
                            child: Text(
                                '${u['fullName'] ?? u['email'] ?? ''} (${u['role'] ?? ''})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _loadSalesperson(v);
                  },
                ),
                if (_selectedUserId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _recordTxn(isIssue: true),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Issue'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _recordTxn(isIssue: false),
                        icon: const Icon(Icons.keyboard_return),
                        label: const Text('Return'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_balance.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No sample activity for this salesperson'),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          const ListTile(
                            dense: true,
                            title: Text('Product'),
                            trailing: SizedBox(
                              width: 230,
                              child: Row(
                                children: [
                                  Expanded(child: Text('Issued')),
                                  Expanded(child: Text('Ret.')),
                                  Expanded(child: Text('Dist.')),
                                  Expanded(child: Text('Bal.')),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ..._balance.map((r) {
                            final bal = (r['balance'] as num?) ?? 0;
                            return ListTile(
                              dense: true,
                              title: Text(r['productName']?.toString() ?? ''),
                              trailing: SizedBox(
                                width: 230,
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${r['issued']}')),
                                    Expanded(child: Text('${r['returned']}')),
                                    Expanded(
                                        child: Text('${r['distributed']}')),
                                    Expanded(
                                      child: Text(
                                        '$bal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: bal < 0 ? Colors.red : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Recent transactions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._transactions.take(20).map((t) => ListTile(
                        dense: true,
                        leading: Icon(
                          t['txnType'] == 'ISSUE'
                              ? Icons.add_box_outlined
                              : Icons.keyboard_return,
                          color: t['txnType'] == 'ISSUE'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                            '${t['productName']} × ${t['quantity']}'),
                        subtitle: Text(
                            '${t['txnType']} • ${t['txnDate']}'
                            '${(t['notes'] ?? '').toString().isNotEmpty ? ' • ${t['notes']}' : ''}'),
                      )),
                ],
              ],
            ),
    );
  }
}
