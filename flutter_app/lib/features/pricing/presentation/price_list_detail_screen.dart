import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/price_list_repository.dart';

/// Detail view for a single price list. Shows metadata + all
/// tiered items grouped by item. Supports adding new tiers via a
/// bottom sheet and deleting existing tiers with a confirmation.
class PriceListDetailScreen extends ConsumerWidget {
  final String listId;
  const PriceListDetailScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(priceListDetailProvider(listId));
    final itemsAsync = ref.watch(priceListItemsProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price List'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: KColors.error),
                  SizedBox(width: 8),
                  Text('Delete list'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const KLoading(),
        error: (err, st) {
          debugPrint('[PriceListDetail] header ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load price list',
            onRetry: () => ref.invalidate(priceListDetailProvider(listId)),
          );
        },
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(priceListDetailProvider(listId));
              ref.invalidate(priceListItemsProvider(listId));
            },
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                _HeaderCard(list: list),
                KSpacing.vGapLg,
                Row(
                  children: [
                    Text('Tiers', style: KTypography.h3),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddTierSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Tier'),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                itemsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: KLoading(),
                  ),
                  error: (err, st) {
                    debugPrint('[PriceListDetail] items ERROR: $err\n$st');
                    return KErrorView(
                      message: 'Failed to load tiers',
                      onRetry: () =>
                          ref.invalidate(priceListItemsProvider(listId)),
                    );
                  },
                  data: (tiers) {
                    if (tiers.isEmpty) {
                      return _EmptyTiers(
                        onAdd: () => _showAddTierSheet(context, ref),
                      );
                    }
                    // Group by itemId so multiple tiers on one item
                    // render as stacked rows inside a single card.
                    final grouped = <String, List<Map<String, dynamic>>>{};
                    for (final t in tiers) {
                      final itemId = t['itemId']?.toString() ?? '';
                      grouped.putIfAbsent(itemId, () => []).add(t);
                    }
                    final entries = grouped.entries.toList();
                    return Column(
                      children: [
                        for (final entry in entries) ...[
                          _ItemTierGroup(
                            tiers: entry.value,
                            currency: list['currency']?.toString() ?? 'INR',
                            onDeleteTier: (itemRowId) =>
                                _deleteTier(context, ref, itemRowId),
                          ),
                          KSpacing.vGapSm,
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTierSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Tier'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this price list?'),
        content: const Text(
          'Customers pinned to this list will fall through to the org '
          'default. This cannot be undone from the app.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(priceListRepositoryProvider).deletePriceList(listId);
      ref.invalidate(priceListsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price list deleted')),
      );
      context.go('/price-lists');
    } catch (e, st) {
      debugPrint('[PriceListDetail] delete FAILED: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete price list')),
      );
    }
  }

  Future<void> _deleteTier(
      BuildContext context, WidgetRef ref, String itemRowId) async {
    try {
      await ref.read(priceListRepositoryProvider).deleteItem(itemRowId);
      ref.invalidate(priceListItemsProvider(listId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tier removed')),
      );
    } catch (e, st) {
      debugPrint('[PriceListDetail] deleteTier FAILED: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove tier')),
      );
    }
  }

  Future<void> _showAddTierSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddTierSheet(listId: listId),
      ),
    );
    ref.invalidate(priceListItemsProvider(listId));
  }
}

// ── Header card ──────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic> list;
  const _HeaderCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final name = list['name']?.toString() ?? 'Unnamed list';
    final currency = list['currency']?.toString() ?? 'INR';
    final description = list['description']?.toString() ?? '';
    final isDefault = list['isDefault'] == true;
    final active = list['active'] != false;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: KColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sell_outlined,
                    color: KColors.primary, size: 24),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: KTypography.h3),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        Text('Currency: $currency',
                            style: KTypography.bodySmall),
                        if (isDefault) ...[
                          KSpacing.hGapSm,
                          _StatusChip(
                              label: 'Default', color: KColors.primary),
                        ],
                        if (!active) ...[
                          KSpacing.hGapSm,
                          _StatusChip(
                              label: 'Inactive',
                              color: KColors.textSecondary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            KSpacing.vGapSm,
            Text(description, style: KTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: KTypography.labelSmall
              .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────

class _EmptyTiers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTiers({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.layers_outlined,
              size: 44, color: KColors.textHint),
          KSpacing.vGapSm,
          Text('No tiers yet', style: KTypography.labelLarge),
          KSpacing.vGapXs,
          Text(
            'Add tiered prices so bigger orders get better rates '
            'automatically at invoice time.',
            style: KTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          KSpacing.vGapMd,
          KButton(
            label: 'Add First Tier',
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── Tier group ───────────────────────────────────────────────────────

class _ItemTierGroup extends StatelessWidget {
  final List<Map<String, dynamic>> tiers;
  final String currency;
  final void Function(String itemRowId) onDeleteTier;

  const _ItemTierGroup({
    required this.tiers,
    required this.currency,
    required this.onDeleteTier,
  });

  @override
  Widget build(BuildContext context) {
    // Sort tiers by minQuantity DESC so the highest-volume rate is
    // shown first — matches how the resolver walks them.
    final sorted = [...tiers]..sort((a, b) {
        final qa = (a['minQuantity'] as num?)?.toDouble() ?? 0;
        final qb = (b['minQuantity'] as num?)?.toDouble() ?? 0;
        return qb.compareTo(qa);
      });
    final itemName = sorted.first['itemName']?.toString() ??
        sorted.first['itemSku']?.toString() ??
        'Item';

    return KCard(
      title: itemName,
      subtitle: '${sorted.length} tier${sorted.length == 1 ? "" : "s"}',
      child: Column(
        children: [
          for (final tier in sorted) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_fmtQty(tier['minQuantity'])}+',
                      style: KTypography.labelMedium
                          .copyWith(color: KColors.primary),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Text(
                      CurrencyFormatter.formatIndian(
                          (tier['price'] as num?)?.toDouble() ?? 0),
                      style: KTypography.amountSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove tier',
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: KColors.error),
                    onPressed: () {
                      final id = tier['id']?.toString();
                      if (id != null) onDeleteTier(id);
                    },
                  ),
                ],
              ),
            ),
            if (tier != sorted.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  String _fmtQty(dynamic q) {
    final n = (q as num?)?.toDouble() ?? 0;
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n.toString();
  }
}

// ── Add tier sheet ───────────────────────────────────────────────────

class _AddTierSheet extends ConsumerStatefulWidget {
  final String listId;
  const _AddTierSheet({required this.listId});

  @override
  ConsumerState<_AddTierSheet> createState() => _AddTierSheetState();
}

class _AddTierSheetState extends ConsumerState<_AddTierSheet> {
  final _formKey = GlobalKey<FormState>();
  final _minQtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  String? _itemId;
  String? _itemName;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _minQtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      _itemId = picked['id']?.toString();
      _itemName = picked['name']?.toString() ?? '';
      // Seed the price with the item's current salePrice as a
      // reasonable default for the 1+ tier.
      final salePrice = (picked['salePrice'] as num?)?.toDouble() ?? 0;
      if (_priceController.text.isEmpty || _priceController.text == '0') {
        _priceController.text = salePrice.toString();
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_itemId == null) {
      setState(() => _errorMessage = 'Select an item first');
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(priceListRepositoryProvider).addItem(widget.listId, {
        'itemId': _itemId,
        'minQuantity': double.parse(_minQtyController.text),
        'price': double.parse(_priceController.text),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tier added for $_itemName')),
      );
    } on DioException catch (e) {
      debugPrint('[AddTierSheet] DioException: ${e.response?.data}');
      final code = (e.response?.data is Map)
          ? (e.response!.data as Map)['errorCode']?.toString()
          : null;
      setState(() {
        _errorMessage = code == 'PRICING_DUPLICATE_TIER'
            ? 'A tier at this quantity already exists for this item. '
                'Edit or delete it first.'
            : 'Failed to add tier. Please try again.';
      });
    } catch (e, st) {
      debugPrint('[AddTierSheet] save FAILED: $e\n$st');
      setState(() => _errorMessage = 'Failed to add tier.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Add Tier', style: KTypography.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Text(
              'Set the minimum quantity at which this price applies. '
              'The resolver picks the highest-minQuantity tier that '
              'fits the invoice quantity.',
              style: KTypography.bodySmall,
            ),
            KSpacing.vGapMd,
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KColors.error.withValues(alpha: 0.08),
                  borderRadius: KSpacing.borderRadiusMd,
                  border:
                      Border.all(color: KColors.error.withValues(alpha: 0.4)),
                ),
                child: Text(_errorMessage!,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.error)),
              ),
              KSpacing.vGapMd,
            ],
            InkWell(
              onTap: _pickItem,
              borderRadius: KSpacing.borderRadiusMd,
              child: Container(
                padding: const EdgeInsets.all(KSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: KSpacing.borderRadiusMd,
                  border: Border.all(color: KColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: KColors.primary),
                    KSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        _itemName ?? 'Select item',
                        style: KTypography.bodyMedium.copyWith(
                          color: _itemName == null
                              ? KColors.textHint
                              : KColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: KColors.textHint),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Min Quantity',
                    controller: _minQtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final parsed = double.tryParse(v);
                      if (parsed == null || parsed <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField.amount(
                    label: 'Price',
                    controller: _priceController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final parsed = double.tryParse(v);
                      if (parsed == null || parsed < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,
            KButton(
              label: 'Add Tier',
              icon: Icons.check,
              fullWidth: true,
              isLoading: _saving,
              onPressed: _save,
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }
}
