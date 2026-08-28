import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/inventory_repository.dart';

final _recallProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, rmBatchId) {
  return ref.watch(inventoryRepositoryProvider).getBatchRecall(rmBatchId);
});

/// Batch recall screen — pharma/food regulatory tool. Salesperson or QA
/// types in a suspect raw-material batch id; the screen pulls every FG
/// batch it was mixed into and every customer shipment of those FG
/// batches so the recall team can phone the affected customers.
class BatchRecallScreen extends ConsumerStatefulWidget {
  final String? initialBatchId;
  const BatchRecallScreen({super.key, this.initialBatchId});

  @override
  ConsumerState<BatchRecallScreen> createState() => _BatchRecallScreenState();
}

class _BatchRecallScreenState extends ConsumerState<BatchRecallScreen> {
  final _searchCtrl = TextEditingController();
  String? _rmBatchId;

  @override
  void initState() {
    super.initState();
    if (widget.initialBatchId != null) {
      _searchCtrl.text = widget.initialBatchId!;
      _rmBatchId = widget.initialBatchId;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Recall Coordinator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _searchCtrl,
                    label: 'Suspect Raw Material (RM) Batch Number / ID',
                    hint: 'Paste the batch UUID from the batch list / GRN',
                    prefixIcon: Icons.warning_amber_outlined,
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(
                  icon: Icons.search,
                  label: 'Execute Recall Trace',
                  onPressed: _run,
                ),
              ],
            ),
          ),
          Expanded(
            child: _rmBatchId == null
                ? const KEmptyState(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Enter Suspect Batch Number',
                    subtitle: 'Audit and track downstream Finished Goods (FG) and customer shipments for regulatory quarantine and recall coordination.',
                  )
                : _RecallView(rmBatchId: _rmBatchId!),
          ),
        ],
      ),
    );
  }

  void _run() {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _rmBatchId = text);
  }
}

class _RecallView extends ConsumerWidget {
  final String rmBatchId;
  const _RecallView({required this.rmBatchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_recallProvider(rmBatchId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Executing regulatory batch recall trace...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (report) {
        final rmInfo = (report['rmBatch'] as Map?) ?? {};
        final fgBatches = (report['affectedFgBatches'] as List?) ?? [];
        final shipments = (report['affectedShipments'] as List?) ?? [];

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        decoration: BoxDecoration(
                          color: KColors.error.withValues(alpha: 0.12),
                          borderRadius: KSpacing.borderRadiusSm,
                        ),
                        child: const Icon(Icons.warning_rounded, color: KColors.error, size: 24),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suspect RM Batch: ${rmInfo['batchNumber'] ?? rmBatchId}',
                              style: KTypography.titleMedium,
                            ),
                            if (rmInfo['expiryDate'] != null) ...[
                              KSpacing.vGapXs,
                              Text(
                                'Expiry Date: ${rmInfo['expiryDate']}',
                                style: KTypography.mono(fontSize: 12, color: KColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const KStatusChip(status: 'RECALL_ACTIVE'),
                    ],
                  ),
                  KSpacing.vGapMd,
                  const Divider(height: 1),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Affected FG Batches',
                          value: '${fgBatches.length}',
                          color: fgBatches.isNotEmpty ? KColors.warning : KColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'Dispatched Customer Shipments',
                          value: '${shipments.length}',
                          color: shipments.isNotEmpty ? KColors.error : KColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            if (shipments.isEmpty)
              KCard(
                child: Row(
                  children: [
                    Icon(
                      fgBatches.isEmpty ? Icons.check_circle_outline : Icons.info_outline,
                      color: fgBatches.isEmpty ? KColors.success : KColors.info,
                      size: 24,
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        fgBatches.isEmpty
                            ? 'This RM batch has not been consumed in any work order yet — no customer stock at risk.'
                            : 'The affected FG batches have not been shipped yet — immediately block warehouse stock from dispatch.',
                        style: KTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text('Shipments to Recall (${shipments.length} outbound orders)', style: KTypography.titleMedium),
              KSpacing.vGapSm,
              ...shipments.map((s) => _ShipmentTile(shipment: s as Map<String, dynamic>)),
            ],
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: KTypography.mono(fontSize: 22, fontWeight: FontWeight.w700, color: color),
        ),
        KSpacing.vGapXs,
        Text(label, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
      ],
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final Map<String, dynamic> shipment;
  const _ShipmentTile({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = shipment['invoiceNumber']?.toString() ?? '—';
    final qty = shipment['quantity']?.toString() ?? '0';
    final date = shipment['movementDate']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusSm,
              ),
              child: const Icon(Icons.local_shipping_outlined, color: KColors.error, size: 20),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shipment['customerName']?.toString() ?? 'Unknown Customer', style: KTypography.titleSmall),
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Text('Invoice: ', style: KTypography.caption),
                      Text(
                        invoiceNumber,
                        style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: KColors.primary),
                      ),
                      KSpacing.hGapMd,
                      Text('Dispatched: ', style: KTypography.caption),
                      Text('$qty units', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (date.isNotEmpty) ...[
                        KSpacing.hGapSm,
                        Text('• $date', style: KTypography.caption),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const KStatusChip(status: 'DISPATCHED'),
          ],
        ),
      ),
    );
  }
}
