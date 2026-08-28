import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

class JobWorkDetailScreen extends ConsumerStatefulWidget {
  const JobWorkDetailScreen({super.key, required this.jobWorkId});
  final String jobWorkId;

  @override
  ConsumerState<JobWorkDetailScreen> createState() => _JobWorkDetailScreenState();
}

class _JobWorkDetailScreenState extends ConsumerState<JobWorkDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final order = await repo.getJobWorkOrder(widget.jobWorkId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: KLoading(message: 'Loading job work order...')));
    if (_error != null) return Scaffold(body: KErrorView(message: _error!, onRetry: _load));
    if (_order == null) return const Scaffold(body: KErrorView(message: 'Job work order not found'));

    final order = _order!;
    final status = order['status']?.toString() ?? '';
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    final matCost = (order['totalMaterialCost'] as num?)?.toDouble();
    final procCharges = (order['processingCharges'] as num?)?.toDouble();
    final totalCost = (order['totalCost'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(order['jobWorkNumber']?.toString() ?? 'Job Work Order'),
        actions: _buildActions(status, order),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // Status banner
            _StatusBanner(status: status),
            KSpacing.vGapMd,

            // GST deadline card
            _GstDeadlineCard(deadline: order['gstReturnDeadline']?.toString()),
            KSpacing.vGapMd,

            // Overview card
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: KTypography.titleMedium),
                    const Divider(height: 20),
                    _InfoRow('Status', status.replaceAll('_', ' ')),
                    _InfoRow('Vendor ID', order['vendorId']?.toString() ?? '-', isMono: true),
                    _InfoRow('Warehouse ID', order['warehouseId']?.toString() ?? '-', isMono: true),
                    if (order['challanNumber'] != null)
                      _InfoRow('Challan No.', order['challanNumber'].toString(), isMono: true),
                    if (order['plannedSendDate'] != null)
                      _InfoRow('Planned Send', order['plannedSendDate'].toString()),
                    if (order['plannedReturnDate'] != null)
                      _InfoRow('Planned Return', order['plannedReturnDate'].toString()),
                    if (order['actualSendDate'] != null)
                      _InfoRow('Actual Send', order['actualSendDate'].toString()),
                    if (order['actualReturnDate'] != null)
                      _InfoRow('Actual Return', order['actualReturnDate'].toString()),
                    if (order['notes'] != null &&
                        (order['notes'] as String).isNotEmpty)
                      _InfoRow('Notes', order['notes'].toString()),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,

            // Costing card
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Costing & Charges', style: KTypography.titleMedium),
                    const Divider(height: 20),
                    _CostRow('Material Cost', matCost),
                    _CostRow('Processing Charges', procCharges),
                    const Divider(height: 16),
                    _CostRow('Total Cost', totalCost, isBold: true),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,

            // Lines card
            Text('Material Lines', style: KTypography.titleMedium),
            KSpacing.vGapSm,
            if (lines.isEmpty)
              const KEmptyState(icon: Icons.list_alt, title: 'No material lines', subtitle: '')
            else
              KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Column(
                    children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Item',
                                  style: KTypography.labelSmall.copyWith(color: KColors.textSecondary)),
                            ),
                            _ColHeader('Sent'),
                            _ColHeader('Recv'),
                            _ColHeader('Waste'),
                            SizedBox(
                              width: 80,
                              child: Text('Status',
                                  style: KTypography.labelSmall.copyWith(color: KColors.textSecondary),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...lines.map((line) => _LineRow(line: line)),
                    ],
                  ),
                ),
              ),

            KSpacing.vGapLg,

            // Action buttons
            ..._buildBottomActions(status),

            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(String status, Map<String, dynamic> order) {
    final actions = <Widget>[];

    if (status == 'DRAFT') {
      actions.add(IconButton(
        icon: const Icon(Icons.local_shipping_outlined),
        tooltip: 'Send Materials',
        onPressed: () => _confirmSend(),
      ));
    }

    if (status == 'SENT' || status == 'PARTIALLY_RECEIVED') {
      actions.add(IconButton(
        icon: const Icon(Icons.move_to_inbox),
        tooltip: 'Receive Goods',
        onPressed: () => _showReceiveDialog(order),
      ));
    }

    if (status == 'DRAFT' || status == 'SENT' || status == 'PARTIALLY_RECEIVED') {
      actions.add(PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'cancel') _confirmCancel();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'cancel', child: Text('Cancel Order')),
        ],
      ));
    }

    return actions;
  }

  List<Widget> _buildBottomActions(String status) {
    final widgets = <Widget>[];

    if (status == 'DRAFT') {
      widgets.add(KButton.primary(
        fullWidth: true,
        onPressed: _confirmSend,
        icon: Icons.local_shipping_outlined,
        label: 'Send Materials',
      ));
      widgets.add(KSpacing.vGapSm);
      widgets.add(KButton.danger(
        fullWidth: true,
        onPressed: _confirmCancel,
        icon: Icons.cancel_outlined,
        label: 'Cancel Order',
      ));
    }

    if (status == 'SENT' || status == 'PARTIALLY_RECEIVED') {
      widgets.add(KButton.primary(
        fullWidth: true,
        onPressed: () => _showReceiveDialog(_order!),
        icon: Icons.move_to_inbox,
        label: 'Receive Goods',
      ));
      widgets.add(KSpacing.vGapSm);
      widgets.add(KButton.danger(
        fullWidth: true,
        onPressed: _confirmCancel,
        icon: Icons.cancel_outlined,
        label: 'Cancel Order',
      ));
    }

    return widgets;
  }

  Future<void> _confirmSend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Materials'),
        content: const Text(
            'This will mark materials as sent to the subcontractor and generate a delivery challan. Continue?'),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'No',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Send Materials',
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(manufacturingRepositoryProvider).sendJobWorkMaterials(widget.jobWorkId);
      _invalidateAndReload('Materials sent successfully');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this job work order?'),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'No',
          ),
          KSpacing.hGapSm,
          KButton.danger(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Cancel Order',
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(manufacturingRepositoryProvider).cancelJobWorkOrder(widget.jobWorkId);
      _invalidateAndReload('Job work order cancelled');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showReceiveDialog(Map<String, dynamic> order) async {
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    final receiptControllers = <String, ({TextEditingController received, TextEditingController wastage})>{};
    for (final line in lines) {
      final itemId = line['itemId']?.toString() ?? '';
      receiptControllers[itemId] = (
        received: TextEditingController(text: '0'),
        wastage: TextEditingController(text: '0'),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Goods'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter received and wastage quantities for each item.',
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                ),
                KSpacing.vGapMd,
                ...lines.map((line) {
                  final itemId = line['itemId']?.toString() ?? '';
                  final shortId = itemId.length > 8 ? itemId.substring(0, 8) : itemId;
                  final ctls = receiptControllers[itemId];
                  if (ctls == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$shortId... (sent: ${line['sentQty'] ?? 0})',
                          style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ctls.received,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Received Qty',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            KSpacing.hGapSm,
                            Expanded(
                              child: TextField(
                                controller: ctls.wastage,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Wastage Qty',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Receive',
          ),
        ],
      ),
    );

    for (final ctls in receiptControllers.values) {
      ctls.received.dispose();
      ctls.wastage.dispose();
    }

    if (confirmed != true) return;

    final receiptLines = <Map<String, dynamic>>[];
    try {
      await ref
          .read(manufacturingRepositoryProvider)
          .receiveJobWorkGoods(widget.jobWorkId, receiptLines);
      _invalidateAndReload('Goods received');
    } catch (e) {
      _showError(e);
    }
  }

  void _invalidateAndReload(String message) {
    ref.invalidate(jobWorkOrdersProvider(null));
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: KColors.success),
      );
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Status banner
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KColors.border),
      ),
      child: Row(
        children: [
          KStatusChip(status: status),
          KSpacing.hGapSm,
          Text(
            status.replaceAll('_', ' '),
            style: KTypography.titleSmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GST deadline card
// ---------------------------------------------------------------------------

class _GstDeadlineCard extends StatelessWidget {
  const _GstDeadlineCard({required this.deadline});
  final String? deadline;

  @override
  Widget build(BuildContext context) {
    if (deadline == null) return const SizedBox.shrink();

    DateTime? deadlineDate;
    try {
      deadlineDate = DateTime.parse(deadline!);
    } catch (_) {}

    final isUrgent = deadlineDate != null &&
        deadlineDate.difference(DateTime.now()).inDays <= 30;
    final isPast = deadlineDate != null && deadlineDate.isBefore(DateTime.now());

    final color = isPast
        ? KColors.error
        : isUrgent
            ? KColors.warning
            : KColors.success;

    final label = isPast
        ? 'GST ITC-04 deadline PASSED'
        : isUrgent
            ? 'GST ITC-04 deadline approaching'
            : 'GST ITC-04 deadline';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isPast ? Icons.warning_rounded : Icons.event_note,
            color: color,
            size: 20,
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                Text(
                  deadline!,
                  style: KTypography.mono(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.isMono = false});
  final String label;
  final String value;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: isMono ? KTypography.mono(fontSize: 13) : KTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow(this.label, this.value, {this.isBold = false});
  final String label;
  final double? value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? KTypography.labelLarge
                : KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          if (value != null)
            KMoney(value!)
          else
            Text('-', style: KTypography.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table column header
// ---------------------------------------------------------------------------

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(color: KColors.textSecondary),
        textAlign: TextAlign.right,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Line row in the materials table
// ---------------------------------------------------------------------------

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final Map<String, dynamic> line;

  @override
  Widget build(BuildContext context) {
    final itemId = line['itemId']?.toString() ?? '';
    final shortId = itemId.length > 8 ? '${itemId.substring(0, 8)}...' : itemId;
    final status = line['status']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              shortId,
              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          _QtyCell(line['sentQty']),
          _QtyCell(line['receivedQty']),
          _QtyCell(line['wastageQty']),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: KStatusChip(status: status),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyCell extends StatelessWidget {
  const _QtyCell(this.value);
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Text(
        value?.toString() ?? '0',
        style: KTypography.mono(fontSize: 12),
        textAlign: TextAlign.right,
      ),
    );
  }
}
