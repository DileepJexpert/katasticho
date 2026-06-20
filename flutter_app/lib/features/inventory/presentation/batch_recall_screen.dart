import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
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
      appBar: AppBar(title: const Text('Batch Recall')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Suspect RM batch id',
                      helperText:
                          'Paste the batch UUID from the batch list / GRN',
                      prefixIcon: Icon(Icons.warning_amber_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.search),
                  label: const Text('Recall'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _rmBatchId == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.health_and_safety_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter an RM batch id to start a recall trace'),
                      ],
                    ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (report) {
        final rmInfo = (report['rmBatch'] as Map?) ?? {};
        final fgBatches = (report['affectedFgBatches'] as List?) ?? [];
        final shipments = (report['affectedShipments'] as List?) ?? [];

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            'RM batch: ${rmInfo['batchNumber'] ?? rmBatchId}',
                            style: KTypography.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (rmInfo['expiryDate'] != null)
                      Text('Expiry: ${rmInfo['expiryDate']}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _Stat(
                          label: 'Affected FG batches',
                          value: '${fgBatches.length}',
                        ),
                        _Stat(
                          label: 'Customer shipments',
                          value: '${shipments.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            if (shipments.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Text(
                    fgBatches.isEmpty
                        ? 'This RM batch has not been consumed in any work order yet — nothing to recall.'
                        : 'The affected FG batches have not been shipped yet — block the stock before it goes out.',
                  ),
                ),
              ),
            if (shipments.isNotEmpty)
              Text('Shipments to recall (newest first)',
                  style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.sm),
            ...shipments.map((s) => _ShipmentTile(shipment: s as Map<String, dynamic>)),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: KTypography.h3),
        Text(label, style: KTypography.bodySmall),
      ],
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final Map<String, dynamic> shipment;
  const _ShipmentTile({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(shipment['customerName']?.toString() ?? 'Unknown customer'),
        subtitle: Text(
          'Invoice ${shipment['invoiceNumber'] ?? '—'} • '
          'Qty ${shipment['quantity']} • '
          '${shipment['movementDate'] ?? ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
