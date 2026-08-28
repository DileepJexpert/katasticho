import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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
    if (_loading) return const Scaffold(body: Center(child: KLoading(message: 'Loading work order...')));
    if (_error != null) return Scaffold(body: KErrorView(message: _error!, onRetry: _load));
    if (_order == null) return const Scaffold(body: KErrorView(message: 'Work order not found'));

    final order = _order!;
    final status = order['status']?.toString() ?? '';
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            order['workOrderNumber']?.toString() ?? 'Work Order',
            if (order['finishedGoodName'] != null)
              order['finishedGoodName'].toString(),
          ].join(' · '),
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildActions(status),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            Row(
              children: [
                Text(
                  order['workOrderNumber']?.toString() ?? 'Work Order',
                  style: KTypography.mono(fontSize: 16, weight: FontWeight.w700),
                ),
                const Spacer(),
                KStatusChip(status: status),
              ],
            ),
            KSpacing.vGapMd,

            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: KTypography.titleSmall),
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
            KSpacing.vGapMd,

            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Costing', style: KTypography.titleSmall),
                    const Divider(height: 20),
                    _MoneyInfoRow('Raw Material', (order['rawMaterialCost'] as num?)?.toDouble() ?? 0),
                    _MoneyInfoRow('Direct Labor', (order['directLaborCost'] as num?)?.toDouble() ?? 0),
                    _MoneyInfoRow('Overhead', (order['overheadCost'] as num?)?.toDouble() ?? 0),
                    const Divider(height: 12),
                    _MoneyInfoRow('Total Cost', (order['totalCost'] as num?)?.toDouble() ?? 0, isTotal: true),
                    _MoneyInfoRow('Unit Cost', (order['unitCost'] as num?)?.toDouble() ?? 0),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,

            Text('BOM Lines', style: KTypography.titleSmall),
            KSpacing.vGapSm,
            if (lines.isEmpty)
              const KEmptyState(icon: Icons.list, title: 'No BOM lines', subtitle: 'No component items required.')
            else
              ...lines.map((line) {
                final unitCost = (line['unitCost'] as num?)?.toDouble() ?? 0;
                final lineCost = (line['lineCost'] as num?)?.toDouble() ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (line['itemName'] ?? line['itemId'])?.toString() ?? 'Item',
                                  style: KTypography.labelLarge,
                                ),
                              ),
                              KStatusChip(status: line['status']?.toString() ?? ''),
                            ],
                          ),
                          KSpacing.vGapSm,
                          Row(
                            children: [
                              Text('Req: ${line['requiredQty']} · Issued: ${line['issuedQty'] ?? 0}',
                                  style: KTypography.bodySmall),
                              const Spacer(),
                              Text('Unit: ', style: KTypography.bodySmall),
                              KMoney(unitCost, size: KMoneySize.small),
                              KSpacing.hGapSm,
                              Text('Total: ', style: KTypography.bodySmall),
                              KMoney(lineCost, size: KMoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
            case 'sub_assembly':
              _cascadeSubAssemblyWos();
            case 'split':
              _showSplitDialog();
            case 'cancel':
              _confirmAction('Cancel Work Order', _cancelWorkOrder);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'costs', child: Text('Update Costs')),
          if (status == 'DRAFT')
            const PopupMenuItem(
                value: 'sub_assembly',
                child: Text('Cascade sub-assembly WOs')),
          if (status == 'DRAFT')
            const PopupMenuItem(
                value: 'split',
                child: Text('Split work order')),
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
          KButton.outlined(
            label: 'No',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Yes',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
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

  /// Prompts for the qty to keep on the original WO; the residual goes
  /// to a new sibling DRAFT (tracker #64). Refuses zero or the full
  /// quantity server-side, but we let the server be the source of
  /// truth — just collect the number and POST.
  Future<void> _showSplitDialog() async {
    final ctl = TextEditingController();
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Split Work Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantity to keep on this WO; the residual goes to a new sibling DRAFT.',
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity to keep'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Split',
            size: KButtonSize.small,
            onPressed: () {
              final v = double.tryParse(ctl.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
          ),
        ],
      ),
    );
    if (qty == null) return;
    try {
      final result = await ref
          .read(manufacturingRepositoryProvider)
          .splitWorkOrder(widget.workOrderId, qty);
      _invalidateAndReload(
          'Split into ${result.length} work orders — refresh the list to see the sibling');
    } catch (e) {
      _showError(e);
    }
  }

  /// Cascade DRAFT child WOs for any COMPOSITE sub-assembly in this WO's
  /// BOM (tracker #60). Idempotent on the server — skips sub-assemblies
  /// that already have an open WO, so repeated taps are safe.
  Future<void> _cascadeSubAssemblyWos() async {
    try {
      final created = await ref
          .read(manufacturingRepositoryProvider)
          .createSubAssemblyWos(widget.workOrderId);
      if (!mounted) return;
      final msg = created.isEmpty
          ? 'No new sub-assemblies — none in BOM or all already drafted'
          : 'Created ${created.length} sub-assembly work order(s)';
      _invalidateAndReload(msg);
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
                KSpacing.vGapSm,
                Text(
                  'Batch (required when the FG item tracks batches — mandatory for pharma + food)',
                  style: KTypography.caption.copyWith(color: KColors.textHint),
                ),
                TextField(
                  controller: batchCtl,
                  decoration: const InputDecoration(labelText: 'Batch number'),
                ),
                KSpacing.vGapSm,
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
            KButton.outlined(
              label: 'Cancel',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
            ),
            KSpacing.hGapSm,
            KButton.primary(
              label: 'Receive',
              size: KButtonSize.small,
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
            KTextField.amount(
              controller: laborCtl,
              label: 'Direct Labor Cost',
            ),
            KSpacing.vGapSm,
            KTextField.amount(
              controller: overheadCtl,
              label: 'Overhead Cost',
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Update',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
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
        SnackBar(content: Text(message), backgroundColor: KColors.success),
      );
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: KTypography.bodyMedium)),
        ],
      ),
    );
  }
}

class _MoneyInfoRow extends StatelessWidget {
  const _MoneyInfoRow(this.label, this.amount, {this.isTotal = false});
  final String label;
  final double amount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: isTotal
                  ? KTypography.labelMedium
                  : KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: KMoney(
                amount,
                size: isTotal ? KMoneySize.medium : KMoneySize.small,
                style: isTotal ? const TextStyle(fontWeight: FontWeight.w700) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
