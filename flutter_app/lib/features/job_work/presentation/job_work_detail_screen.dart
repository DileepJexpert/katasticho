import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/job_work_models.dart';
import '../data/job_work_repository.dart';

class JobWorkChallan45DetailScreen extends ConsumerWidget {
  final String orderId;

  const JobWorkChallan45DetailScreen({
    super.key,
    required this.orderId,
  });

  void _showReceiveModal(BuildContext context, WidgetRef ref, JobWorkOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveGoodsSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(jobWorkOrderProvider(orderId));

    return orderAsync.when(
      loading: () => const Scaffold(body: KLoading()),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Job Work Order Detail')),
        body: KErrorView(
          message: 'Failed to load order: $err',
          onRetry: () => ref.invalidate(jobWorkOrderProvider(orderId)),
        ),
      ),
      data: (order) {
        final isCompleted = order.status == 'COMPLETED';

        return Scaffold(
          appBar: AppBar(
            title: Text('Order ${order.orderNumber}'),
            actions: [
              if (!isCompleted)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: KButton(
                    label: 'Record Inward Goods',
                    icon: Icons.download_outlined,
                    onPressed: () => _showReceiveModal(context, ref, order),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: KSpacing.pagePadding,
            children: [
              // Header Summary Card
              KCard(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.jobWorkerName, style: KTypography.h2),
                            if (order.jobWorkerGstin != null)
                              Text('GSTIN: ${order.jobWorkerGstin}',
                                  style: KTypography.mono(
                                      fontSize: 12, color: KColors.textSecondary)),
                          ],
                        ),
                        KStatusChip(
                          status: isCompleted ? 'PAID' : 'SENT',
                          label: order.status,
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    const Divider(),
                    KSpacing.vGapSm,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Date: ${order.orderDate}', style: KTypography.caption),
                        if (order.expectedReturnDate != null)
                          Text('Expected Return: ${order.expectedReturnDate}',
                              style: KTypography.caption),
                        Row(
                          children: [
                            Text('Issued Value: ', style: KTypography.caption),
                            KMoney(order.totalIssuedValue),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.vGapLg,

              // Issued Lines Section
              Text('Issued Raw Materials (Challan 45)', style: KTypography.h3),
              KSpacing.vGapSm,
              ...order.issueLines.map((iss) => Container(
                    margin: const EdgeInsets.only(bottom: KSpacing.sm),
                    child: KCard(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.outbox, color: KColors.primary),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(iss.itemName, style: KTypography.labelLarge),
                                Text(
                                  'Challan: ${iss.challanNumber} • HSN: ${iss.hsnCode ?? "-"}',
                                  style: KTypography.caption.copyWith(color: KColors.textSecondary),
                                ),
                                if (iss.natureOfProcessing != null)
                                  Text('Process: ${iss.natureOfProcessing}',
                                      style: KTypography.caption),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Issued: ${iss.issuedQuantity} ${iss.uom}',
                                style: KTypography.mono(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Pending: ${iss.pendingQuantity} ${iss.uom}',
                                style: KTypography.mono(
                                    fontSize: 11,
                                    color: iss.pendingQuantity > 0
                                        ? KColors.warning
                                        : KColors.success),
                              ),
                            ],
                          ),
                          KSpacing.hGapMd,
                          KMoney(iss.taxableValue),
                        ],
                      ),
                    ),
                  )),
              KSpacing.vGapLg,

              // Receipt Lines Section
              Text('Received Finished Goods (Inward Goods)', style: KTypography.h3),
              KSpacing.vGapSm,
              if (order.receiptLines.isEmpty)
                const KCard(
                  padding: EdgeInsets.all(KSpacing.md),
                  child: Text('No inward goods receipts recorded yet.'),
                )
              else
                ...order.receiptLines.map((rec) => Container(
                      margin: const EdgeInsets.only(bottom: KSpacing.sm),
                      child: KCard(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: Row(
                          children: [
                            const Icon(Icons.move_to_inbox, color: KColors.success),
                            KSpacing.hGapMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rec.finishedItemName, style: KTypography.labelLarge),
                                  Text(
                                    'Inward Challan: ${rec.inwardChallanNumber} • Date: ${rec.receiptDate}',
                                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                                  ),
                                  if (rec.consumedRawItemName != null)
                                    Text(
                                      'Consumed: ${rec.consumedQuantity} of ${rec.consumedRawItemName} (Scrap: ${rec.scrapQuantity})',
                                      style: KTypography.caption,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Received: ${rec.receivedQuantity} ${rec.uom}',
                                  style: KTypography.mono(fontWeight: FontWeight.w700),
                                ),
                                if (rec.jobWorkCharges > 0) ...[
                                  Text('Charges:', style: KTypography.caption),
                                  KMoney(rec.jobWorkCharges),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECEIVE GOODS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiveGoodsSheet extends ConsumerStatefulWidget {
  final JobWorkOrderModel order;

  const _ReceiveGoodsSheet({required this.order});

  @override
  ConsumerState<_ReceiveGoodsSheet> createState() => _ReceiveGoodsSheetState();
}

class _ReceiveGoodsSheetState extends ConsumerState<_ReceiveGoodsSheet> {
  String? _selectedFinishedItemId;
  String? _selectedRawItemId;
  final _inwardChallanCtl = TextEditingController(text: 'INW-001');
  final _receivedQtyCtl = TextEditingController(text: '98');
  final _consumedQtyCtl = TextEditingController(text: '100');
  final _scrapQtyCtl = TextEditingController(text: '2');
  final _chargesCtl = TextEditingController(text: '2500');
  final _notesCtl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.issueLines.isNotEmpty) {
      _selectedRawItemId = widget.order.issueLines.first.itemId;
      _consumedQtyCtl.text = widget.order.issueLines.first.pendingQuantity.toString();
    }
  }

  @override
  void dispose() {
    _inwardChallanCtl.dispose();
    _receivedQtyCtl.dispose();
    _consumedQtyCtl.dispose();
    _scrapQtyCtl.dispose();
    _chargesCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedFinishedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select finished item received')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final req = ReceiveJobWorkRequest(
        inwardChallanNumber: _inwardChallanCtl.text.trim(),
        receiptDate: DateTime.now().toIso8601String().split('T').first,
        finishedItemId: _selectedFinishedItemId!,
        receivedQuantity: double.tryParse(_receivedQtyCtl.text.trim()) ?? 0.0,
        consumedRawItemId: _selectedRawItemId,
        consumedQuantity: double.tryParse(_consumedQtyCtl.text.trim()) ?? 0.0,
        scrapQuantity: double.tryParse(_scrapQtyCtl.text.trim()) ?? 0.0,
        jobWorkCharges: double.tryParse(_chargesCtl.text.trim()) ?? 0.0,
        notes: _notesCtl.text.trim().isNotEmpty ? _notesCtl.text.trim() : null,
      );

      await ref.read(jobWorkRepositoryProvider).recordReceipt(widget.order.id, req);
      ref.invalidate(jobWorkOrderProvider(widget.order.id));
      ref.invalidate(jobWorkOrdersProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inward goods receipt recorded successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(jobWorkItemsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Record Inward Goods Receipt', style: KTypography.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,

            KTextField(
              label: 'Inward Delivery Challan No *',
              controller: _inwardChallanCtl,
            ),
            KSpacing.vGapSm,

            // Finished item picker
            itemsAsync.when(
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _selectedFinishedItemId,
                decoration: const InputDecoration(labelText: 'Finished Good Received *'),
                items: items.map((i) => DropdownMenuItem(
                      value: i['id']?.toString(),
                      child: Text('${i['name']} (${i['sku'] ?? "-"})'),
                    )).toList(),
                onChanged: (v) => setState(() => _selectedFinishedItemId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Received Qty *',
                    controller: _receivedQtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Raw Qty Consumed *',
                    controller: _consumedQtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Process Scrap Qty',
                    controller: _scrapQtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Job Work Charges (₹)',
                    controller: _chargesCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSaving ? 'Recording...' : 'Record Goods Receipt',
              icon: Icons.save,
              isLoading: _isSaving,
              onPressed: _submit,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
