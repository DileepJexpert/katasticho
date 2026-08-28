import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/item_repository.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  List<Map<String, dynamic>> _currentItems = const [];
  String? _searchQuery;
  bool _negativeStockOnly = false;
  String _typeFilter = 'ALL'; // ALL, GOODS, SERVICE, LOW_STOCK
  final Set<String> _selectedIds = {};

  ItemListFilter get _filter =>
      (search: _searchQuery, negativeStockOnly: _negativeStockOnly);

  static void _refreshAll(WidgetRef ref) {
    ref.invalidate(itemListProvider);
    ref.invalidate(negativeStockCountProvider);
  }

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentItems.length) return;
    final id = _currentItems[index]['id']?.toString();
    if (id != null) context.go('/items/$id');
  }

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count item${count == 1 ? '' : 's'}?'),
        content:
            const Text('Items used in open transactions cannot be deleted.'),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.danger(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(itemRepositoryProvider);
    final ids = _selectedIds.toList();
    int success = 0, failed = 0;
    for (final id in ids) {
      try {
        await repo.deleteItem(id);
        success++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    _refreshAll(ref);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Deleted $success item${success == 1 ? '' : 's'}'
          : 'Deleted $success, $failed failed'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider(_filter));
    final negStockCountAsync = ref.watch(negativeStockCountProvider);
    final inSelection = _selectedIds.isNotEmpty;

    return KKeyboardListWrapper(
      itemCount: () => _currentItems.length,
      onNew: () => context.go(Routes.itemCreate),
      onRefresh: () => _refreshAll(ref),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Items & Inventory',
            searchHint: 'Search by SKU, item name, barcode, HSN...',
            onSearchChanged: (q) => setState(
                () => _searchQuery = q.trim().isEmpty ? null : q.trim()),
            actions: inSelection
                ? null
                : [
                    _NegativeStockChip(
                      active: _negativeStockOnly,
                      count: negStockCountAsync.maybeWhen(
                        data: (c) => c,
                        orElse: () => null,
                      ),
                      onTap: () => setState(
                          () => _negativeStockOnly = !_negativeStockOnly),
                    ),
                    IconButton(
                      tooltip: 'Item groups (variant templates)',
                      icon: const Icon(Icons.category_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(Routes.itemGroups),
                    ),
                    IconButton(
                      tooltip: 'Bulk import from CSV',
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.go(Routes.itemImport),
                    ),
                  ],
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) {
                debugPrint('[ItemListScreen] ERROR: $err\n$st');
                return KErrorView(
                  message: 'Failed to load items',
                  onRetry: () => _refreshAll(ref),
                );
              },
              data: (data) {
                final content = data['data'];
                final items = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (items.isEmpty) {
                  if (_negativeStockOnly) {
                    return const KEmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No negative-stock items',
                      subtitle:
                          'Every tracked item has on-hand ≥ 0 — nothing to reconcile right now.',
                    );
                  }
                  return KEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _searchQuery == null
                        ? 'No items yet'
                        : 'No items match "$_searchQuery"',
                    subtitle: _searchQuery == null
                        ? 'Add your first item to start tracking inventory'
                        : 'Try a different search term',
                    actionLabel: _searchQuery == null ? 'Add Item' : null,
                    onAction: _searchQuery == null
                        ? () => context.go(Routes.itemCreate)
                        : null,
                  );
                }

                final itemMaps = items
                    .whereType<Map>()
                    .map((item) => item.cast<String, dynamic>())
                    .toList();
                _currentItems = itemMaps;

                // Calculate ERP KPIs
                final totalSkus = itemMaps.length;
                final lowStockCount = itemMaps.where((i) {
                  final onHand = (i['totalOnHand'] as num?)?.toDouble() ?? 0;
                  final reorder = (i['reorderLevel'] as num?)?.toDouble() ?? 0;
                  final track = i['trackInventory'] as bool? ?? true;
                  return track && reorder > 0 && onHand <= reorder && onHand > 0;
                }).length;
                final outOfStockCount = itemMaps.where((i) {
                  final onHand = (i['totalOnHand'] as num?)?.toDouble() ?? 0;
                  final track = i['trackInventory'] as bool? ?? true;
                  return track && onHand <= 0;
                }).length;
                final totalStockValue = itemMaps.fold<double>(0.0, (acc, i) {
                  final onHand = (i['totalOnHand'] as num?)?.toDouble() ?? 0;
                  final price = (i['purchasePrice'] as num?)?.toDouble() ??
                      (i['salePrice'] as num?)?.toDouble() ??
                      0;
                  return acc + (onHand > 0 ? onHand * price : 0);
                });

                // Apply local type filter if active
                final filteredItems = itemMaps.where((item) {
                  if (_typeFilter == 'GOODS') {
                    return (item['itemType'] as String? ?? 'GOODS') == 'GOODS';
                  } else if (_typeFilter == 'SERVICE') {
                    return (item['itemType'] as String?) == 'SERVICE';
                  } else if (_typeFilter == 'LOW_STOCK') {
                    final onHand = (item['totalOnHand'] as num?)?.toDouble() ?? 0;
                    final reorder = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
                    final track = item['trackInventory'] as bool? ?? true;
                    return track && (onHand <= 0 || (reorder > 0 && onHand <= reorder));
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    // ── ERP KPI Metrics Ribbon ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          _ItemStatCard(
                            label: 'Total SKUs',
                            value: '$totalSkus',
                            icon: Icons.inventory_2_outlined,
                            iconColor: KColors.primary,
                          ),
                          KSpacing.hGapSm,
                          _ItemStatCard(
                            label: 'Low Stock',
                            value: '$lowStockCount',
                            icon: Icons.warning_amber_rounded,
                            iconColor: KColors.warning,
                            onTap: () => setState(() => _typeFilter = _typeFilter == 'LOW_STOCK' ? 'ALL' : 'LOW_STOCK'),
                            isActive: _typeFilter == 'LOW_STOCK',
                          ),
                          KSpacing.hGapSm,
                          _ItemStatCard(
                            label: 'Out of Stock',
                            value: '$outOfStockCount',
                            icon: Icons.error_outline_rounded,
                            iconColor: KColors.error,
                            onTap: () => setState(() => _negativeStockOnly = !_negativeStockOnly),
                            isActive: _negativeStockOnly,
                          ),
                          KSpacing.hGapSm,
                          _ItemStatCard(
                            label: 'Est. Stock Value',
                            valueWidget: KMoney(
                              totalStockValue,
                              size: KMoneySize.small,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: KColors.success,
                          ),
                        ],
                      ),
                    ),

                    // ── Quick Filter Tabs ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.xs,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChoiceChip(
                              label: 'All (${itemMaps.length})',
                              selected: _typeFilter == 'ALL' && !_negativeStockOnly,
                              onSelected: () => setState(() {
                                _typeFilter = 'ALL';
                                _negativeStockOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChoiceChip(
                              label: 'Goods',
                              selected: _typeFilter == 'GOODS',
                              onSelected: () => setState(() {
                                _typeFilter = 'GOODS';
                                _negativeStockOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChoiceChip(
                              label: 'Services',
                              selected: _typeFilter == 'SERVICE',
                              onSelected: () => setState(() {
                                _typeFilter = 'SERVICE';
                                _negativeStockOnly = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChoiceChip(
                              label: 'Low / Out of Stock',
                              selected: _typeFilter == 'LOW_STOCK',
                              badgeCount: lowStockCount + outOfStockCount,
                              badgeColor: KColors.warning,
                              onSelected: () => setState(() {
                                _typeFilter = 'LOW_STOCK';
                                _negativeStockOnly = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: KResponsiveEntityList<Map<String, dynamic>>(
                        items: filteredItems,
                        onRefresh: () async => _refreshAll(ref),
                        mobileItemBuilder: (context, item) {
                          final id = item['id']?.toString() ?? '';
                          return _ItemCard(
                            item: item,
                            selected: _selectedIds.contains(id),
                            inSelection: inSelection,
                            onToggleSelect: () => _toggleSelect(id),
                          );
                        },
                        tableBuilder: (context) => _ItemTable(
                          items: filteredItems,
                          selectedIds: _selectedIds,
                          onToggleSelect: _toggleSelect,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.go(Routes.itemCreate),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              tooltip: 'Add Item (N)',
            ),
    ),
    );
  }
}

class _ItemStatCard extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool isActive;

  const _ItemStatCard({
    required this.label,
    this.value,
    this.valueWidget,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? iconColor.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
          border: Border.all(
            color: isActive
                ? iconColor
                : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                valueWidget ??
                    Text(
                      value ?? '',
                      style: KTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int? badgeCount;
  final Color? badgeColor;

  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount != null && badgeCount! > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? KColors.primary).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? KColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;

  const _ItemTable({
    required this.items,
    required this.selectedIds,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 18,
      horizontalMargin: 12,
      columns: const [
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
        DataColumn(label: Text('Item / SKU')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('HSN')),
        DataColumn(label: Text('Stock Level')),
        DataColumn(label: Text('Sale Price'), numeric: true),
        DataColumn(label: Text('Purchase Cost'), numeric: true),
        DataColumn(label: Text('Status')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: items.map((item) {
        final id = item['id']?.toString() ?? '';
        final name = item['name'] as String? ?? 'Unknown';
        final sku = item['sku'] as String? ?? '--';
        final itemType = item['itemType'] as String? ?? 'GOODS';
        final hsn = (item['hsnCode'] ?? item['hsn'])?.toString() ?? '--';
        final salePrice = (item['salePrice'] as num?)?.toDouble() ?? 0;
        final purchasePrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0;
        final active = item['active'] as bool? ?? true;
        final trackInventory = item['trackInventory'] as bool? ?? true;
        final onHand = (item['totalOnHand'] as num?)?.toDouble();
        final reorderLevel = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
        final selected = selectedIds.contains(id);

        return DataRow(
          selected: selected,
          color: kEntityRowColor(context, selected: selected),
          onSelectChanged: (_) => onToggleSelect(id),
          cells: [
            DataCell(KTableSelectionCell(
              selected: selected,
              onChanged: (_) => onToggleSelect(id),
            )),
            DataCell(_ItemNameCell(name: name, sku: sku)),
            DataCell(KTableTextCell(value: _formatItemType(itemType))),
            DataCell(Text(hsn, style: KTypography.mono(size: 12))),
            DataCell(_ItemStockCell(
              trackInventory: trackInventory,
              onHand: onHand,
              reorderLevel: reorderLevel,
            )),
            DataCell(KMoney(salePrice, size: KMoneySize.small)),
            DataCell(KMoney(purchasePrice, size: KMoneySize.small)),
            DataCell(KStatusChip(
              status: active ? 'PAID' : 'CANCELLED',
              label: active ? 'Active' : 'Inactive',
              dense: true,
            )),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open item',
              onPressed: id.isEmpty ? null : () => context.go('/items/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _ItemNameCell extends StatelessWidget {
  final String name;
  final String sku;

  const _ItemNameCell({
    required this.name,
    required this.sku,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 17,
              color: KColors.primary,
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sku,
                  style: KTypography.mono(
                    size: 11,
                    color: KColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemStockCell extends StatelessWidget {
  final bool trackInventory;
  final double? onHand;
  final double reorderLevel;

  const _ItemStockCell({
    required this.trackInventory,
    required this.onHand,
    required this.reorderLevel,
  });

  @override
  Widget build(BuildContext context) {
    if (!trackInventory) {
      return Text(
        'Not tracked',
        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
      );
    }

    final qty = onHand ?? 0;
    final isNegative = qty < 0;
    final isLow = !isNegative && reorderLevel > 0 && qty <= reorderLevel;
    final color = isNegative
        ? KColors.error
        : (isLow ? KColors.warning : KColors.textSecondary);
    final icon = isNegative
        ? Icons.error_outline
        : (isLow ? Icons.warning_amber_rounded : Icons.inventory_outlined);
    return SizedBox(
      width: 148,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isNegative
                  ? '${_formatQty(qty)} · needs stock'
                  : '${_formatQty(qty)} on hand',
              style: KTypography.bodySmall.copyWith(
                color: color,
                fontWeight:
                    (isNegative || isLow) ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NegativeStockChip extends StatelessWidget {
  final bool active;
  final int? count;
  final VoidCallback onTap;

  const _NegativeStockChip({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = (count ?? 0) > 0;
    final tint = active || has ? KColors.error : KColors.textSecondary;
    return Tooltip(
      message: active
          ? 'Showing items with negative stock — tap to clear'
          : 'Show items sold without stock (needs receipt)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.error : Icons.error_outline,
                size: 18,
                color: tint,
              ),
              const SizedBox(width: 4),
              Text(
                'Needs stock',
                style: KTypography.bodySmall.copyWith(
                  color: tint,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (has) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: KTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _ItemCard({
    required this.item,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sku = item['sku'] as String? ?? '';
    final name = item['name'] as String? ?? 'Unknown';
    final salePrice = (item['salePrice'] as num?)?.toDouble() ?? 0;
    final onHand = (item['totalOnHand'] as num?)?.toDouble();
    final reorderLevel = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
    final trackInventory = item['trackInventory'] as bool? ?? true;
    final itemType = item['itemType'] as String? ?? 'GOODS';
    final active = item['active'] as bool? ?? true;

    final isNegative = trackInventory && onHand != null && onHand < 0;
    final isLowStock = !isNegative &&
        trackInventory &&
        onHand != null &&
        onHand <= reorderLevel &&
        reorderLevel > 0;
    final stockColor = isNegative
        ? KColors.error
        : (isLowStock ? KColors.warning : KColors.textSecondary);

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        final id = item['id']?.toString();
        if (id != null) context.go('/items/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: inSelection
                ? Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      size: 24,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: KColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      itemType == 'SERVICE'
                          ? Icons.build_outlined
                          : Icons.inventory_2_outlined,
                      size: 20,
                      color: KColors.primary,
                    ),
                  ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: KTypography.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!active) ...[
                      KSpacing.hGapSm,
                      const KStatusChip(
                          status: 'CANCELLED', label: 'Inactive', dense: true),
                    ],
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  sku,
                  style: KTypography.mono(size: 11, color: KColors.textSecondary),
                ),
                if (trackInventory && onHand != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Icon(
                        isNegative
                            ? Icons.error_outline
                            : (isLowStock
                                ? Icons.warning_amber_rounded
                                : Icons.inventory_outlined),
                        size: 14,
                        color: stockColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${onHand.toStringAsFixed(onHand.truncateToDouble() == onHand ? 0 : 2)} on hand',
                          style: KTypography.bodySmall.copyWith(
                            color: stockColor,
                            fontWeight: (isNegative || isLowStock)
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isNegative) ...[
                        const SizedBox(width: 6),
                        const KStatusChip(
                            status: 'OVERDUE',
                            label: 'Needs stock',
                            dense: true),
                      ] else if (isLowStock) ...[
                        const SizedBox(width: 6),
                        const KStatusChip(
                            status: 'OVERDUE', label: 'Low', dense: true),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          KSpacing.hGapSm,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              KMoney(
                salePrice,
                size: KMoneySize.small,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('Sale price', style: KTypography.labelSmall),
              if (item['mrp'] != null &&
                  (item['mrp'] as num).toDouble() > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('MRP ', style: KTypography.labelSmall.copyWith(color: KColors.textHint, fontSize: 10)),
                    KMoney(
                      (item['mrp'] as num).toDouble(),
                      size: KMoneySize.small,
                      style: TextStyle(color: KColors.textHint, fontSize: 10),
                    ),
                  ],
                ),
                Builder(builder: (_) {
                  final mrp = (item['mrp'] as num).toDouble();
                  final purchase =
                      (item['purchasePrice'] as num?)?.toDouble() ?? 0;
                  if (purchase <= 0 || mrp <= 0) return const SizedBox.shrink();
                  final margin = ((mrp - purchase) / mrp * 100);
                  return Text(
                    '${margin.toStringAsFixed(1)}% margin',
                    style: KTypography.labelSmall.copyWith(
                      color: margin >= 0 ? KColors.success : KColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
              ],
            ],
          ),
          if (!inSelection) ...[
            KSpacing.hGapXs,
            const Icon(Icons.chevron_right, color: KColors.textHint, size: 18),
          ],
        ],
      ),
    );
  }
}

String _formatQty(double value) {
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _formatItemType(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0] + part.substring(1).toLowerCase())
      .join(' ');
}
