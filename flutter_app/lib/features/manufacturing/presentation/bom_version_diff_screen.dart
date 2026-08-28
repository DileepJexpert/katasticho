import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

/// Compare two BOM versions of the same parent item side-by-side.
class BomVersionDiffScreen extends ConsumerStatefulWidget {
  const BomVersionDiffScreen({super.key});

  @override
  ConsumerState<BomVersionDiffScreen> createState() =>
      _BomVersionDiffScreenState();
}

class _BomVersionDiffScreenState extends ConsumerState<BomVersionDiffScreen> {
  final _parentCtl = TextEditingController();
  final _fromCtl = TextEditingController(text: '1');
  final _toCtl = TextEditingController(text: '2');
  ({String parent, int from, int to})? _query;

  @override
  void dispose() {
    _parentCtl.dispose();
    _fromCtl.dispose();
    _toCtl.dispose();
    super.dispose();
  }

  void _run() {
    final parent = _parentCtl.text.trim();
    final from = int.tryParse(_fromCtl.text.trim());
    final to = int.tryParse(_toCtl.text.trim());
    if (parent.isEmpty || from == null || to == null) return;
    setState(() => _query = (parent: parent, from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BOM Version Diff')),
      body: Column(
        children: [
          Padding(
            padding: KSpacing.pagePadding,
            child: Column(
              children: [
                TextField(
                  controller: _parentCtl,
                  decoration: const InputDecoration(
                    labelText: 'Parent item ID',
                    helperText:
                        'Composite (finished good) item whose BOM is being diffed',
                    border: OutlineInputBorder(),
                  ),
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fromCtl,
                        decoration: const InputDecoration(
                          labelText: 'From version',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: TextField(
                        controller: _toCtl,
                        decoration: const InputDecoration(
                          labelText: 'To version',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    KSpacing.hGapSm,
                    KButton.primary(
                      onPressed: _run,
                      icon: Icons.difference,
                      label: 'Diff Versions',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query == null
                ? const KEmptyState(
                    icon: Icons.compare_arrows,
                    title: 'Select versions to compare',
                    subtitle: 'Enter parent item ID and from/to versions to view the change matrix.',
                  )
                : _DiffView(query: _query!),
          ),
        ],
      ),
    );
  }
}

class _DiffView extends ConsumerWidget {
  final ({String parent, int from, int to}) query;
  const _DiffView({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_diffProvider(query));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Comparing BOM revisions...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (diff) {
        final added = (diff['added'] as List?) ?? [];
        final removed = (diff['removed'] as List?) ?? [];
        final changed = (diff['changed'] as List?) ?? [];
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _Stat(label: 'Added', value: '${diff['addedCount']}', color: KColors.success),
                    _Stat(label: 'Removed', value: '${diff['removedCount']}', color: KColors.error),
                    _Stat(label: 'Changed', value: '${diff['changedCount']}', color: KColors.warning),
                    _Stat(
                        label: 'Unchanged',
                        value: '${diff['unchangedCount']}'),
                  ],
                ),
              ),
            ),
            if (added.isNotEmpty) ...[
              KSpacing.vGapMd,
              _SectionHeader(
                  title: 'Added Lines', color: KColors.success, count: added.length),
              ...added.map((r) {
                final row = r as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: KColors.success),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['childItemName']?.toString() ?? row['childItemId'].toString(),
                                  style: KTypography.labelLarge,
                                ),
                                KSpacing.vGapXxs,
                                Text(
                                  'Qty ${row['toQty']} • Scrap ${row['toScrapPercent'] ?? 0}%',
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (removed.isNotEmpty) ...[
              KSpacing.vGapMd,
              _SectionHeader(
                  title: 'Removed Lines', color: KColors.error, count: removed.length),
              ...removed.map((r) {
                final row = r as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_circle_outline, color: KColors.error),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['childItemName']?.toString() ?? row['childItemId'].toString(),
                                  style: KTypography.labelLarge,
                                ),
                                KSpacing.vGapXxs,
                                Text(
                                  'Was Qty ${row['fromQty']}',
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (changed.isNotEmpty) ...[
              KSpacing.vGapMd,
              _SectionHeader(
                  title: 'Changed Lines', color: KColors.warning, count: changed.length),
              ...changed.map((r) {
                final row = r as Map<String, dynamic>;
                final delta = row['qtyDelta'];
                final up = delta is num && delta > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            up ? Icons.arrow_upward : Icons.arrow_downward,
                            color: KColors.warning,
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['childItemName']?.toString() ?? row['childItemId'].toString(),
                                  style: KTypography.labelLarge,
                                ),
                                KSpacing.vGapXxs,
                                Text(
                                  'Qty ${row['fromQty']} → ${row['toQty']} (${up ? '+' : ''}$delta) • '
                                  'Scrap ${row['fromScrapPercent'] ?? 0}% → ${row['toScrapPercent'] ?? 0}%',
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (added.isEmpty && removed.isEmpty && changed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(KSpacing.md),
                child: KEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No differences found',
                  subtitle: 'The two BOM revisions are identical in components and quantities.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int count;
  const _SectionHeader(
      {required this.title, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: color),
          KSpacing.hGapSm,
          Text('$title ($count)',
              style: KTypography.titleMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: KTypography.h3.copyWith(color: color)),
        Text(label, style: KTypography.bodySmall),
      ],
    );
  }
}

final _diffProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String parent, int from, int to})>(
        (ref, q) {
  return ref.watch(manufacturingRepositoryProvider).getBomDiff(
        q.parent,
        fromVersion: q.from,
        toVersion: q.to,
      );
});
