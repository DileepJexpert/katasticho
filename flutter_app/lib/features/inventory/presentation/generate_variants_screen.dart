import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_group_repository.dart';
import '../data/item_repository.dart';

/// Variant matrix bulk-create. Pulls the group's
/// `attributeDefinitions`, builds the full Cartesian product as a
/// scrollable checkbox grid, lets the operator deselect specific cells,
/// then POSTs the surviving combinations to
/// `/api/v1/item-groups/{id}/generate-variants`. The endpoint is
/// idempotent — combos that already exist as live variants come back
/// in `skippedReasons` rather than failing the batch.
class GenerateVariantsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GenerateVariantsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GenerateVariantsScreen> createState() =>
      _GenerateVariantsScreenState();
}

class _GenerateVariantsScreenState
    extends ConsumerState<GenerateVariantsScreen> {
  /// Each generated combination keyed by its serialised form
  /// `size=S|color=Red`, value is whether it's currently selected.
  final Map<String, bool> _selection = {};

  /// Ordered list of combos so the UI doesn't flicker on rebuild.
  List<Map<String, String>> _combos = const [];
  bool _submitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
  }

  /// Cartesian product of every attribute's allowed values, in the
  /// order the group declares them — matches the backend's `mintSku`
  /// iteration order so the previewed SKU is what actually lands.
  List<Map<String, String>> _cartesian(List<dynamic> defs) {
    if (defs.isEmpty) return const [];
    List<Map<String, String>> acc = [<String, String>{}];
    for (final d in defs) {
      final def = d as Map<String, dynamic>;
      final key = def['key']?.toString() ?? '';
      final values = (def['values'] as List?) ?? const [];
      if (values.isEmpty) continue;
      final next = <Map<String, String>>[];
      for (final partial in acc) {
        for (final v in values) {
          next.add({...partial, key: v.toString()});
        }
      }
      acc = next;
    }
    return acc;
  }

  String _comboKey(Map<String, String> combo) {
    final entries = combo.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  String _previewSku(String? prefix, Map<String, String> combo,
      List<dynamic> defs) {
    final p = (prefix == null || prefix.isEmpty) ? '???' : prefix;
    final parts = <String>[];
    for (final d in defs) {
      final def = d as Map<String, dynamic>;
      final key = def['key']?.toString() ?? '';
      final v = combo[key];
      if (v != null && v.isNotEmpty) {
        parts.add(v.toUpperCase().replaceAll(RegExp(r'\s+'), ''));
      }
    }
    return parts.isEmpty ? p : '$p-${parts.join('-')}';
  }

  Future<void> _submit() async {
    final selected = _combos
        .where((c) => _selection[_comboKey(c)] ?? false)
        .toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one combination')),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      final repo = ref.read(itemGroupRepositoryProvider);
      final result = await repo.generateVariants(widget.groupId, selected);
      final body = (result['data'] ?? result) as Map<String, dynamic>;
      final created = (body['created'] as List?) ?? const [];
      final skipped = (body['skippedReasons'] as List?) ?? const [];
      // Refresh both the variants list on the detail screen and the
      // global item list/picker, since the new variants are regular
      // Item rows that the rest of the app cares about.
      ref.invalidate(itemGroupVariantsProvider(widget.groupId));
      ref.invalidate(itemGroupDetailProvider(widget.groupId));
      ref.invalidate(itemGroupListProvider);
      ref.invalidate(itemListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${created.length} variants created, ${skipped.length} skipped')),
      );
      context.pop();
    } catch (e, st) {
      debugPrint('[GenerateVariants] FAILED: $e\n$st');
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(itemGroupDetailProvider(widget.groupId));
    final variantsAsync = ref.watch(itemGroupVariantsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Variants')),
      body: groupAsync.when(
        loading: () => const KLoading(),
        error: (err, st) => KErrorView(message: 'Failed to load group: $err'),
        data: (raw) {
          final group = (raw['data'] ?? raw) as Map<String, dynamic>;
          final defs = (group['attributeDefinitions'] as List?) ?? const [];
          final skuPrefix = group['skuPrefix']?.toString();

          if (skuPrefix == null || skuPrefix.isEmpty) {
            return Padding(
              padding: KSpacing.pagePadding,
              child: KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: KColors.warning),
                      KSpacing.vGapSm,
                      Text('SKU prefix required',
                          style: KTypography.labelLarge),
                      KSpacing.vGapXs,
                      Text(
                        'The matrix generator mints child SKUs from the group\'s prefix. Set a prefix in the group settings before generating variants.',
                        style: KTypography.bodySmall,
                      ),
                      KSpacing.vGapMd,
                      KButton(
                        label: 'Edit Group',
                        onPressed: () =>
                            context.go('/item-groups/${widget.groupId}/edit'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (defs.isEmpty) {
            return Padding(
              padding: KSpacing.pagePadding,
              child: KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Text(
                    'This group has no attribute definitions yet. Add at least one attribute (e.g. size or colour) before generating variants.',
                    style: KTypography.bodySmall,
                  ),
                ),
              ),
            );
          }

          // Recompute the Cartesian product on each build but only
          // initialise the selection map once — re-toggling shouldn't
          // wipe the user's deselects.
          final newCombos = _cartesian(defs);
          if (_combos.isEmpty || _combos.length != newCombos.length) {
            _combos = newCombos;
            _selection.clear();
            // Pre-tick combos that don't already exist as variants.
            final existing = variantsAsync.maybeWhen(
              data: (variants) {
                return variants
                    .map<String>((v) {
                      final attrs = ((v as Map<String, dynamic>)['variantAttributes']
                              as Map?) ??
                          const {};
                      final m = attrs.map((k, val) =>
                          MapEntry(k.toString(), val.toString()));
                      return _comboKey(m);
                    })
                    .toSet();
              },
              orElse: () => <String>{},
            );
            for (final combo in _combos) {
              final k = _comboKey(combo);
              _selection[k] = !existing.contains(k);
            }
          }

          final selectedCount =
              _combos.where((c) => _selection[_comboKey(c)] ?? false).length;

          return Column(
            children: [
              Padding(
                padding: KSpacing.pagePadding,
                child: KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group['name']?.toString() ?? '',
                            style: KTypography.h3),
                        KSpacing.vGapXs,
                        Text(
                          '${_combos.length} possible combinations · $selectedCount selected',
                          style: KTypography.bodySmall,
                        ),
                        KSpacing.vGapSm,
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                for (final c in _combos) {
                                  _selection[_comboKey(c)] = true;
                                }
                              }),
                              child: const Text('Select all'),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                for (final c in _combos) {
                                  _selection[_comboKey(c)] = false;
                                }
                              }),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: KSpacing.pagePadding,
                  itemCount: _combos.length,
                  separatorBuilder: (_, __) => KSpacing.vGapXs,
                  itemBuilder: (context, index) {
                    final combo = _combos[index];
                    final key = _comboKey(combo);
                    final selected = _selection[key] ?? false;
                    final sku = _previewSku(skuPrefix, combo, defs);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected,
                      onChanged: (v) =>
                          setState(() => _selection[key] = v ?? false),
                      title: Text(sku, style: KTypography.labelLarge),
                      subtitle: Text(
                        combo.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join(' · '),
                        style: KTypography.bodySmall,
                      ),
                    );
                  },
                ),
              ),
              if (_serverError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: KSpacing.sm),
                  child: Text(
                    _serverError!,
                    style: KTypography.bodySmall.copyWith(color: KColors.error),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: KButton(
                    label: 'Generate $selectedCount Variants',
                    fullWidth: true,
                    isLoading: _submitting,
                    onPressed: selectedCount == 0 ? null : _submit,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
