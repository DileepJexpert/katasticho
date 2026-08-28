import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Parameterized BOM resolver preview (tracker #42).
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
            padding: KSpacing.pagePadding,
            child: Column(
              children: [
                TextField(
                  controller: _itemCtl,
                  decoration: const InputDecoration(
                    labelText: 'Parent (composite) Item ID',
                    helperText:
                        'The COMPOSITE item whose BOM you want to resolve for a variant',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                KSpacing.vGapSm,
                ..._pairs.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: p.key,
                            decoration: const InputDecoration(
                              labelText: 'Attribute key',
                              hintText: 'e.g. size',
                            ),
                          ),
                        ),
                        KSpacing.hGapSm,
                        Expanded(
                          child: TextField(
                            controller: p.val,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              hintText: 'e.g. M',
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
                KSpacing.vGapSm,
                Row(
                  children: [
                    KButton.outlined(
                      size: KButtonSize.small,
                      onPressed: _addPair,
                      icon: Icons.add,
                      label: 'Add Attribute',
                    ),
                    const Spacer(),
                    KButton.primary(
                      size: KButtonSize.small,
                      onPressed: _resolve,
                      icon: Icons.tune,
                      label: 'Resolve BOM',
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
                    icon: Icons.filter_alt_outlined,
                    title: 'No parameters specified',
                    subtitle: 'Enter a parent item ID and attributes to preview the dynamic BOM.',
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
      loading: () => const Center(child: KLoading(message: 'Resolving BOM...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.search_off,
            title: 'No matching lines',
            subtitle: 'No BOM lines match the specified attribute combination.',
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        isUniversal ? Icons.check_circle_outline : Icons.tune,
                        color: isUniversal ? KColors.success : KColors.primary,
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Child: ${r['childItemId']}',
                              style: KTypography.labelLarge,
                            ),
                            KSpacing.vGapXs,
                            Text(
                              'Qty ${r['quantity']}${r['scrapPercent'] != null ? ' • Scrap ${r['scrapPercent']}%' : ''}${!isUniversal ? '\nFilter: $filter' : ''}',
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
