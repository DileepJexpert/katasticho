import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
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
            Tab(text: 'Forward Trace (Sale & Dispatch)'),
            Tab(text: 'Backward Trace (Receipt & Supply)'),
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
                  child: KTextField(
                    controller: _searchCtrl,
                    label: 'Batch ID / Batch Number',
                    hint: 'e.g. BATCH-2026-001',
                    prefixIcon: Icons.qr_code_scanner_outlined,
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(
                  icon: Icons.search,
                  label: 'Trace Batch',
                  onPressed: _search,
                ),
              ],
            ),
          ),
          Expanded(
            child: !_searched
                ? const KEmptyState(
                    icon: Icons.track_changes_outlined,
                    title: 'Enter a Batch Number',
                    subtitle: 'Search any lot number to view full backward supplier origin or forward customer distribution genealogy.',
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
      loading: () => const Center(child: KLoading(message: 'Tracing batch genealogy...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (trace) {
        final movements = trace['movements'] as List? ?? [];
        final batchNumber = trace['batchNumber'] as String? ?? batchId;
        final itemName = trace['itemName'] as String? ?? 'Unknown Item';

        if (movements.isEmpty) {
          return KEmptyState(
            icon: Icons.history_toggle_off_outlined,
            title: 'No Movements Found',
            subtitle: traceType == 'forward'
                ? 'No outgoing sales or dispatch movements found for batch $batchNumber.'
                : 'No incoming supplier receipt or production movements found for batch $batchNumber.',
          );
        }

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.12),
                      borderRadius: KSpacing.borderRadiusSm,
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: KColors.primary, size: 24),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemName, style: KTypography.titleMedium),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Text('Batch Number: ', style: KTypography.caption),
                            Text(
                              batchNumber,
                              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  KStatusChip(status: traceType == 'forward' ? 'OUTGOING' : 'INCOMING'),
                ],
              ),
            ),
            KSpacing.vGapMd,
            Text('Movement Timeline (${movements.length} events)', style: KTypography.titleSmall),
            KSpacing.vGapSm,
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
    final qty = movement['quantity'];
    final refNo = movement['referenceNumber']?.toString();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: KColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: KColors.border,
                    ),
                  ),
              ],
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        KStatusChip(status: movementType),
                        const Spacer(),
                        if (movement['movementDate'] != null)
                          Text(
                            movement['movementDate'].toString(),
                            style: KTypography.mono(fontSize: 11, color: KColors.textSecondary),
                          ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        Text('Quantity: ', style: KTypography.caption),
                        Text('$qty', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (movement['warehouseName'] != null) ...[
                          KSpacing.hGapMd,
                          Text('Warehouse: ', style: KTypography.caption),
                          Text('${movement['warehouseName']}', style: KTypography.bodySmall),
                        ],
                      ],
                    ),
                    if (refNo != null && refNo.isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Row(
                        children: [
                          Text('Reference: ', style: KTypography.caption),
                          Text(
                            refNo,
                            style: KTypography.mono(fontSize: 11, color: KColors.primary),
                          ),
                        ],
                      ),
                    ],
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
