import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});
  final String workOrderId;

  @override
  ConsumerState<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final order = await repo.getWorkOrder(widget.workOrderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: KErrorView(message: _error!, onRetry: _load));
    if (_order == null) return const Scaffold(body: KErrorView(message: 'Work order not found'));

    final order = _order!;
    final status = order['status']?.toString() ?? '';
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(order['workOrderNumber']?.toString() ?? 'Work Order'),
        actions: _buildActions(status),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: status),
            const SizedBox(height: 16),

            KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const Divider(height: 20),
                    _InfoRow('Status', status),
                    _InfoRow('Qty to Produce', order['quantityToProduce']?.toString() ?? '0'),
                    _InfoRow('Qty Produced', order['quantityProduced']?.toString() ?? '0'),
                    if (order['plannedStartDate'] != null)
                      _InfoRow('Planned Start', order['plannedStartDate'].toString()),
                    if (order['plannedEndDate'] != null)
                      _InfoRow('Planned End', order['plannedEndDate'].toString()),
                    if (order['actualStartDate'] != null)
                      _InfoRow('Actual Start', order['actualStartDate'].toString()),
                    if (order['actualEndDate'] != null)
                      _InfoRow('Actual End', order['actualEndDate'].toString()),
                    if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
                      _InfoRow('Notes', order['notes'].toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Costing', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const Divider(height: 20),
                    _InfoRow('Raw Material', _currency(order['rawMaterialCost'])),
                    _InfoRow('Direct Labor', _currency(order['directLaborCost'])),
                    _InfoRow('Overhead', _currency(order['overheadCost'])),
                    const Divider(height: 12),
                    _InfoRow('Total Cost', _currency(order['totalCost'])),
                    _InfoRow('Unit Cost', _currency(order['unitCost'])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('BOM Lines', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              const KEmptyState(icon: Icons.list, title: 'No lines', subtitle: '')
            else
              ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                line['itemId']?.toString() ?? 'Item',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            KStatusChip(status: line['status']?.toString() ?? ''),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 16,
                          children: [
                            Text('Required: ${line['requiredQty']}', style: theme.textTheme.bodySmall),
                            Text('Issued: ${line['issuedQty'] ?? 0}', style: theme.textTheme.bodySmall),
                            Text('Unit: ${_currency(line['unitCost'])}', style: theme.textTheme.bodySmall),
                            Text('Line: ${_currency(line['lineCost'])}',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(String status) {
    final actions = <Widget>[];

    if (status == 'DRAFT') {
      actions.add(IconButton(
        icon: const Icon(Icons.play_arrow),
        tooltip: 'Issue to Production',
        onPressed: () => _confirmAction('Issue to Production', _issueToProduction),
      ));
    }

    if (status == 'IN_PROGRESS') {
      actions.add(IconButton(
        icon: const Icon(Icons.inventory_2),
        tooltip: 'Receive Finished Goods',
        onPressed: _showReceiveDialog,
      ));
    }

    if (status == 'DRAFT' || status == 'IN_PROGRESS') {
      actions.add(PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'costs':
              _showCostsDialog();
            case 'cancel':
              _confirmAction('Cancel Work Order', _cancelWorkOrder);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'costs', child: Text('Update Costs')),
          const PopupMenuItem(value: 'cancel', child: Text('Cancel Order')),
        ],
      ));
    }

    return actions;
  }

  Future<void> _confirmAction(String title, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('Are you sure you want to $title?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true) await action();
  }

  Future<void> _issueToProduction() async {
    try {
      await ref.read(manufacturingRepositoryProvider).issueToProduction(widget.workOrderId);
      _invalidateAndReload('Issued to production');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _cancelWorkOrder() async {
    try {
      await ref.read(manufacturingRepositoryProvider).cancelWorkOrder(widget.workOrderId);
      _invalidateAndReload('Work order cancelled');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showReceiveDialog() async {
    final qtyCtl = TextEditingController();
    final batchCtl = TextEditingController();
    DateTime? expiry;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Receive Finished Goods'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: qtyCtl,
                  decoration: const InputDecoration(labelText: 'Quantity Received'),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Batch (required when the FG item tracks batches — '
                  'mandatory for pharma + food)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                TextField(
                  controller: batchCtl,
                  decoration: const InputDecoration(labelText: 'Batch number'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(const Duration(days: 730)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null) setSt(() => expiry = picked);
                        },
                        icon: const Icon(Icons.event),
                        label: Text(expiry == null
                            ? 'Expiry date (optional)'
                            : 'Expiry: ${expiry!.toIso8601String().split("T").first}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtl.text.trim());
                if (qty != null && qty > 0) {
                  Navigator.pop(ctx, {
                    'qty': qty,
                    'batch': batchCtl.text.trim(),
                    'expiry': expiry?.toIso8601String().split('T').first,
                  });
                }
              },
              child: const Text('Receive'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await ref.read(manufacturingRepositoryProvider).receiveFinishedGoods(
            widget.workOrderId,
            result['qty'] as double,
            batchNumber: result['batch'] as String?,
            expiryDate: result['expiry'] as String?,
          );
      _invalidateAndReload('Received ${result['qty']} finished goods');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showCostsDialog() async {
    final laborCtl = TextEditingController(
      text: _order?['directLaborCost']?.toString() ?? '0',
    );
    final overheadCtl = TextEditingController(
      text: _order?['overheadCost']?.toString() ?? '0',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Costs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: laborCtl,
              decoration: const InputDecoration(labelText: 'Direct Labor Cost'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: overheadCtl,
              decoration: const InputDecoration(labelText: 'Overhead Cost'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );

    if (result != true) return;

    try {
      await ref.read(manufacturingRepositoryProvider).updateCosts(
        widget.workOrderId,
        directLaborCost: double.tryParse(laborCtl.text.trim()),
        overheadCost: double.tryParse(overheadCtl.text.trim()),
      );
      _invalidateAndReload('Costs updated');
    } catch (e) {
      _showError(e);
    }
  }

  void _invalidateAndReload(String message) {
    ref.invalidate(workOrdersProvider(null));
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _currency(dynamic value) {
    if (value == null) return '₹0';
    return '₹$value';
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'DRAFT' => (Colors.grey, Icons.edit_note),
      'IN_PROGRESS' => (Colors.blue, Icons.precision_manufacturing),
      'COMPLETED' => (Colors.green, Icons.check_circle),
      'CANCELLED' => (Colors.red, Icons.cancel),
      _ => (Colors.grey, Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            status.replaceAll('_', ' '),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
