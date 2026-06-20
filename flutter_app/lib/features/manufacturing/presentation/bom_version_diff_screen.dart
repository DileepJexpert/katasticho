import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/manufacturing_repository.dart';

/// Compare two BOM versions of the same parent item side-by-side. Paste
/// the parent item id, pick from and to version numbers, get a single
/// table grouped by Added / Removed / Changed (qty delta + scrap delta).
/// Useful for change-control review — "what did engineering actually
/// change between rev 4 and rev 5?".
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
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _parentCtl,
                  decoration: const InputDecoration(
                    labelText: 'Parent item id',
                    helperText:
                        'Composite (finished good) item whose BOM is being diffed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
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
                    const SizedBox(width: KSpacing.sm),
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
                    const SizedBox(width: KSpacing.sm),
                    FilledButton.icon(
                      onPressed: _run,
                      icon: const Icon(Icons.difference),
                      label: const Text('Diff'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _query == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare_arrows,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter parent + versions to compare'),
                      ],
                    ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (diff) {
        final added = (diff['added'] as List?) ?? [];
        final removed = (diff['removed'] as List?) ?? [];
        final changed = (diff['changed'] as List?) ?? [];
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _Stat(label: 'Added', value: '${diff['addedCount']}'),
                    _Stat(label: 'Removed', value: '${diff['removedCount']}'),
                    _Stat(label: 'Changed', value: '${diff['changedCount']}'),
                    _Stat(
                        label: 'Unchanged',
                        value: '${diff['unchangedCount']}'),
                  ],
                ),
              ),
            ),
            if (added.isNotEmpty) ...[
              const SizedBox(height: KSpacing.md),
              _SectionHeader(
                  title: 'Added', color: Colors.green, count: added.length),
              ...added.map((r) {
                final row = r as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.add, color: Colors.green),
                    title: Text(row['childItemName']?.toString() ??
                        row['childItemId'].toString()),
                    subtitle: Text(
                        'Qty ${row['toQty']} • scrap ${row['toScrapPercent'] ?? 0}%'),
                  ),
                );
              }),
            ],
            if (removed.isNotEmpty) ...[
              const SizedBox(height: KSpacing.md),
              _SectionHeader(
                  title: 'Removed', color: Colors.red, count: removed.length),
              ...removed.map((r) {
                final row = r as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.remove, color: Colors.red),
                    title: Text(row['childItemName']?.toString() ??
                        row['childItemId'].toString()),
                    subtitle: Text('Was qty ${row['fromQty']}'),
                  ),
                );
              }),
            ],
            if (changed.isNotEmpty) ...[
              const SizedBox(height: KSpacing.md),
              _SectionHeader(
                  title: 'Changed', color: Colors.orange, count: changed.length),
              ...changed.map((r) {
                final row = r as Map<String, dynamic>;
                final delta = row['qtyDelta'];
                final up = delta is num && delta > 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: ListTile(
                    leading: Icon(
                        up ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.orange),
                    title: Text(row['childItemName']?.toString() ??
                        row['childItemId'].toString()),
                    subtitle: Text(
                        'Qty ${row['fromQty']} → ${row['toQty']} (${up ? '+' : ''}$delta) • '
                        'scrap ${row['fromScrapPercent'] ?? 0}% → ${row['toScrapPercent'] ?? 0}%'),
                  ),
                );
              }),
            ],
            if (added.isEmpty && removed.isEmpty && changed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(KSpacing.md),
                child: Center(child: Text('No differences between the two versions')),
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
          const SizedBox(width: 8),
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

final _diffProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String parent, int from, int to})>(
        (ref, q) {
  return ref.watch(manufacturingRepositoryProvider).getBomDiff(
        q.parent,
        fromVersion: q.from,
        toVersion: q.to,
      );
});
