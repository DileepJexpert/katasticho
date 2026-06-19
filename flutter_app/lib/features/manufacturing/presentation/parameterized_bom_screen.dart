import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Parameterized BOM resolver preview (tracker #42). Engineering pastes
/// a parent (composite) item id and a set of variant attributes, then
/// sees the filtered BOM lines that would apply.
///
/// Useful for:
///   - validating a parameterized BOM after authoring the variant
///     filters
///   - explaining to a planner "what does a Red-M actually use?"
///     before they kick a work order
class ParameterizedBomScreen extends ConsumerStatefulWidget {
  const ParameterizedBomScreen({super.key});

  @override
  ConsumerState<ParameterizedBomScreen> createState() =>
      _ParameterizedBomScreenState();
}

class _ParameterizedBomScreenState
    extends ConsumerState<ParameterizedBomScreen> {
  final _itemCtl = TextEditingController();
  final List<({TextEditingController key, TextEditingController val})> _pairs =
      [];
  ({String itemId, Map<String, String> attrs})? _query;

  @override
  void initState() {
    super.initState();
    _addPair();
  }

  @override
  void dispose() {
    _itemCtl.dispose();
    for (final p in _pairs) {
      p.key.dispose();
      p.val.dispose();
    }
    super.dispose();
  }

  void _addPair() {
    setState(() => _pairs.add((
          key: TextEditingController(),
          val: TextEditingController(),
        )));
  }

  void _removePair(int i) {
    setState(() {
      _pairs[i].key.dispose();
      _pairs[i].val.dispose();
      _pairs.removeAt(i);
    });
  }

  void _resolve() {
    final id = _itemCtl.text.trim();
    if (id.isEmpty) return;
    final attrs = <String, String>{};
    for (final p in _pairs) {
      final k = p.key.text.trim();
      final v = p.val.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) attrs[k] = v;
    }
    setState(() => _query = (itemId: id, attrs: attrs));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parameterized BOM')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _itemCtl,
                  decoration: const InputDecoration(
                    labelText: 'Parent (composite) item id',
                    helperText:
                        'The COMPOSITE item whose BOM you want to resolve for a variant',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                ..._pairs.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: p.key,
                            decoration: const InputDecoration(
                              labelText: 'Attribute key',
                              hintText: 'size',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: p.val,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              hintText: 'M',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed:
                              _pairs.length > 1 ? () => _removePair(i) : null,
                        ),
                      ],
                    ),
                  );
                }),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _addPair,
                      icon: const Icon(Icons.add),
                      label: const Text('Add attribute'),
                    ),
                    const Spacer(),
                    FilledButton(
                        onPressed: _resolve, child: const Text('Resolve')),
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
                        Icon(Icons.filter_alt_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text(
                            'Enter a parent item id + variant attributes to preview the BOM'),
                      ],
                    ),
                  )
                : _ResolvedView(query: _query!),
          ),
        ],
      ),
    );
  }
}

class _ResolvedView extends ConsumerWidget {
  final ({String itemId, Map<String, String> attrs}) query;
  const _ResolvedView({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_resolveProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text('No BOM lines match these attributes'),
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final filter = r['variantFilter'];
            final isUniversal = filter == null ||
                (filter is Map && filter.isEmpty);
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: Icon(isUniversal
                    ? Icons.check_circle_outline
                    : Icons.tune,
                    color: isUniversal ? Colors.green : Colors.blue),
                title: Text('Child ${r['childItemId']}'),
                subtitle: Text(
                  'Qty ${r['quantity']}'
                  '${r['scrapPercent'] != null ? ' • scrap ${r['scrapPercent']}%' : ''}'
                  '${!isUniversal ? '\nFilter: $filter' : ''}',
                  style: KTypography.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final _resolveProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>,
    ({String itemId, Map<String, String> attrs})>((ref, q) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(
    ApiConfig.itemBomResolve(q.itemId),
    queryParameters: q.attrs,
  );
  final data = res.data['data'];
  if (data is List) {
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }
  return [];
});
