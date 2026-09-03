import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/putaway_repository.dart';

class WarehousePutawayDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const WarehousePutawayDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<WarehousePutawayDetailScreen> createState() => _WarehousePutawayDetailScreenState();
}

class _WarehousePutawayDetailScreenState extends ConsumerState<WarehousePutawayDetailScreen> {
  PutawayTaskDto? _task;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(putawayRepositoryProvider);
      final task = await repo.getTask(widget.taskId);
      if (mounted) setState(() => _task = task);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load task details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfirmDialog(PutawayTaskLineDto line) async {
    final rackController = TextEditingController(text: line.suggestedRackId ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bin Putaway'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm placing ${line.quantity} units into rack bin.', style: KTypography.bodyMedium),
            if (line.batchNumber != null) ...[
              KSpacing.vGapXs,
              Text('Batch: ${line.batchNumber}', style: KTypography.labelSmall.copyWith(color: KColors.primary)),
            ],
            KSpacing.vGapMd,
            KTextField(
              controller: rackController,
              label: 'Destination Rack / Bin ID or Barcode',
              hint: 'Scan or enter rack identifier',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          KButton.primary(
            label: 'Confirm Placement',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && rackController.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(putawayRepositoryProvider);
        final updated = await repo.confirmLine(widget.taskId, line.id, rackController.text.trim());
        if (mounted) {
          setState(() => _task = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Putaway line confirmed successfully!'), backgroundColor: KColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to confirm line: $e'), backgroundColor: KColors.error),
          );
        }
      }
    }
  }

  Future<void> _cancelTask() async {
    try {
      final repo = ref.read(putawayRepositoryProvider);
      final updated = await repo.cancelTask(widget.taskId);
      if (mounted) {
        setState(() => _task = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task cancelled'), backgroundColor: KColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel task: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Putaway Task')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Putaway Task')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Task not found', style: const TextStyle(color: KColors.error)),
              KSpacing.vGapMd,
              KButton.secondary(label: 'Retry', onPressed: _loadTask),
            ],
          ),
        ),
      );
    }

    final task = _task!;
    final isDone = task.status == 'COMPLETED' || task.status == 'CANCELLED';

    return Scaffold(
      appBar: AppBar(
        title: Text('Task: ${task.taskNumber}'),
        actions: [
          if (!isDone)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: KColors.error),
              tooltip: 'Cancel Task',
              onPressed: _cancelTask,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTask,
          ),
        ],
      ),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Header Card
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(task.taskNumber, style: KTypography.h2),
                    KStatusChip(status: task.status),
                  ],
                ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    _buildMeta('Source Dock', task.sourceLocation),
                    _buildMeta('Created', task.createdAt.split('T').first),
                    if (task.goodsReceiptId != null) _buildMeta('GRN ID', task.goodsReceiptId!.substring(0, 8)),
                  ],
                ),
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  KSpacing.vGapSm,
                  Text('Notes: ${task.notes}', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                ],
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Staged Items Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Staged Items to Put Away (${task.lines.length})', style: KTypography.labelLarge),
              Text(
                '${task.lines.where((l) => l.status == 'CONFIRMED').length} of ${task.lines.length} confirmed',
                style: KTypography.bodySmall.copyWith(color: KColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          KSpacing.vGapSm,

          // Line Items
          ...task.lines.map((line) => _buildLineCard(line, isDone)),
        ],
      ),
    );
  }

  Widget _buildMeta(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
          KSpacing.vGapXs,
          Text(value, style: KTypography.labelMedium),
        ],
      ),
    );
  }

  Widget _buildLineCard(PutawayTaskLineDto line, bool isTaskDone) {
    final isConfirmed = line.status == 'CONFIRMED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isConfirmed ? KColors.success.withValues(alpha: 0.1) : KColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isConfirmed ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                color: isConfirmed ? KColors.success : KColors.warning,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: ${line.itemId.substring(0, 8)}...',
                      style: KTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Text('Qty: ${line.quantity}', style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      if (line.batchNumber != null) ...[
                        KSpacing.hGapMd,
                        Text('Batch: ${line.batchNumber}',
                            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      ],
                    ],
                  ),
                  if (line.suggestedRackId != null || line.confirmedRackId != null) ...[
                    KSpacing.vGapXs,
                    Text(
                      'Rack: ${line.confirmedRackId ?? line.suggestedRackId ?? 'Unassigned'}',
                      style: KTypography.bodySmall.copyWith(color: isConfirmed ? KColors.success : KColors.textHint),
                    ),
                  ],
                ],
              ),
            ),
            if (!isConfirmed && !isTaskDone)
              KButton.primary(
                label: 'Confirm Bin',
                size: KButtonSize.small,
                onPressed: () => _showConfirmDialog(line),
              )
            else
              KStatusChip(status: line.status),
          ],
        ),
      ),
    );
  }
}