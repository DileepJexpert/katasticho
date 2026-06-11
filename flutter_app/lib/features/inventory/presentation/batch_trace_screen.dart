import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/inventory_repository.dart';

final _forwardTraceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, batchId) {
  return ref.watch(inventoryRepositoryProvider).getBatchForwardTrace(batchId);
});

final _backwardTraceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, batchId) {
  return ref.watch(inventoryRepositoryProvider).getBatchBackwardTrace(batchId);
});

class BatchTraceScreen extends ConsumerStatefulWidget {
  final String? initialBatchId;
  const BatchTraceScreen({super.key, this.initialBatchId});

  @override
  ConsumerState<BatchTraceScreen> createState() => _BatchTraceScreenState();
}

class _BatchTraceScreenState extends ConsumerState<BatchTraceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String? _batchId;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialBatchId != null) {
      _batchId = widget.initialBatchId;
      _searchCtrl.text = widget.initialBatchId!;
      _searched = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Traceability'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Forward Trace'),
            Tab(text: 'Backward Trace'),
          ],
        ),
      ),
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
                      labelText: 'Batch ID / Batch Number',
                      prefixIcon: Icon(Icons.qr_code_scanner_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(
                  onPressed: _search,
                  child: const Text('Trace'),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_searched
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.track_changes_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter a batch ID to trace its movement'),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TraceView(
                        batchId: _batchId!,
                        traceType: 'forward',
                      ),
                      _TraceView(
                        batchId: _batchId!,
                        traceType: 'backward',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _search() {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _batchId = text;
      _searched = true;
    });
  }
}

class _TraceView extends ConsumerWidget {
  final String batchId;
  final String traceType; // 'forward' or 'backward'
  const _TraceView({required this.batchId, required this.traceType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traceAsync = traceType == 'forward'
        ? ref.watch(_forwardTraceProvider(batchId))
        : ref.watch(_backwardTraceProvider(batchId));

    return traceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (trace) {
        final movements = trace['movements'] as List? ?? [];
        final batchNumber = trace['batchNumber'] as String? ?? batchId;
        final itemName = trace['itemName'] as String? ?? 'Unknown Item';

        if (movements.isEmpty) {
          return Center(
            child: Text(
              traceType == 'forward'
                  ? 'No outgoing movements found for batch $batchNumber'
                  : 'No incoming movements found for batch $batchNumber',
            ),
          );
        }

        return ListView(
          padding: KSpacing.screenPadding,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itemName, style: KTypography.titleMedium),
                    Text('Batch: $batchNumber', style: KTypography.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            ...movements.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value as Map<String, dynamic>;
              return _TraceNode(movement: m, index: idx, isLast: idx == movements.length - 1);
            }),
          ],
        );
      },
    );
  }
}

class _TraceNode extends StatelessWidget {
  final Map<String, dynamic> movement;
  final int index;
  final bool isLast;
  const _TraceNode(
      {required this.movement, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final movementType = movement['movementType'] as String? ?? '';
    final color = switch (movementType) {
      'PURCHASE' || 'PURCHASE_RETURN' => KColors.success,
      'SALE' || 'SALES_RETURN' => KColors.info,
      'TRANSFER_IN' || 'TRANSFER_OUT' => Colors.purple,
      'ADJUSTMENT' => KColors.warning,
      _ => KColors.neutral,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KStatusChip(label: movementType, color: color),
                        const Spacer(),
                        Text(
                          movement['movementDate'] as String? ?? '',
                          style: KTypography.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Qty: ${movement['quantity']} • ${movement['warehouseName'] ?? 'N/A'}'),
                    if (movement['referenceNumber'] != null)
                      Text('Ref: ${movement['referenceNumber']}',
                          style: KTypography.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
