import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/item_repository.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  String? _searchQuery;
  final Set<String> _selectedIds = {};

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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
    ref.invalidate(itemListProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Deleted $success item${success == 1 ? '' : 's'}'
          : 'Deleted $success, $failed failed'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider(_searchQuery));
    final inSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Items',
            searchHint: 'Search by SKU or name',
            onSearchChanged: (q) => setState(
                () => _searchQuery = q.trim().isEmpty ? null : q.trim()),
            actions: inSelection
                ? null
                : [
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
                  onRetry: () => ref.invalidate(itemListProvider),
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

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: itemMaps,
                  onRefresh: () async => ref.invalidate(itemListProvider),
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
                    items: itemMaps,
                    selectedIds: _selectedIds,
                    onToggleSelect: _toggleSelect,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Routes.itemCreate),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
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
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('HSN')),
        DataColumn(label: Text('Stock')),
        DataColumn(label: Text('Sale')),
        DataColumn(label: Text('Purchase')),
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
            DataCell(KTableTextCell(value: hsn)),
            DataCell(_ItemStockCell(
              trackInventory: trackInventory,
              onHand: onHand,
              reorderLevel: reorderLevel,
            )),
            DataCell(KTableAmountCell(value: salePrice)),
            DataCell(KTableAmountCell(value: purchasePrice)),
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
                  'SKU $sku',
                  style: KTypography.labelSmall.copyWith(
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
    final isLow = reorderLevel > 0 && qty <= reorderLevel;
    return SizedBox(
      width: 118,
      child: Row(
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.inventory_outlined,
            size: 16,
            color: isLow ? KColors.warning : KColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${_formatQty(qty)} on hand',
              style: KTypography.bodySmall.copyWith(
                color: isLow ? KColors.warning : KColors.textSecondary,
                fontWeight: isLow ? FontWeight.w700 : FontWeight.w500,
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

    final isLowStock = trackInventory &&
        onHand != null &&
        onHand <= reorderLevel &&
        reorderLevel > 0;

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
                Text('SKU: $sku', style: KTypography.bodySmall),
                if (trackInventory && onHand != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 14,
                        color: isLowStock
                            ? KColors.warning
                            : KColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${onHand.toStringAsFixed(onHand.truncateToDouble() == onHand ? 0 : 2)} on hand',
                          style: KTypography.bodySmall.copyWith(
                            color: isLowStock
                                ? KColors.warning
                                : KColors.textSecondary,
                            fontWeight: isLowStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLowStock) ...[
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
              Text(
                CurrencyFormatter.formatIndian(salePrice),
                style: KTypography.amountSmall,
              ),
              Text('Sale price', style: KTypography.labelSmall),
              if (item['mrp'] != null &&
                  (item['mrp'] as num).toDouble() > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'MRP ${CurrencyFormatter.formatIndian((item['mrp'] as num).toDouble())}',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textHint,
                    fontSize: 10,
                  ),
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
