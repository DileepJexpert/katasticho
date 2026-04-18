import 'package:flutter/foundation.dart';
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
        content: const Text(
            'Items used in open transactions cannot be deleted.'),
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
            onSearchChanged: (q) =>
                setState(() => _searchQuery = q.trim().isEmpty ? null : q.trim()),
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
                    : (content is Map ? (content['content'] as List?) ?? [] : []);

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

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(itemListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      final id = item['id']?.toString() ?? '';
                      return _ItemCard(
                        item: item,
                        selected: _selectedIds.contains(id),
                        inSelection: inSelection,
                        onToggleSelect: () => _toggleSelect(id),
                      );
                    },
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

    final isLowStock =
        trackInventory && onHand != null && onHand <= reorderLevel && reorderLevel > 0;

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
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: inSelection
                ? Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      size: 26,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: KColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      itemType == 'SERVICE'
                          ? Icons.build_outlined
                          : Icons.inventory_2_outlined,
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
                      Text(
                        '${onHand.toStringAsFixed(onHand.truncateToDouble() == onHand ? 0 : 2)} on hand',
                        style: KTypography.bodySmall.copyWith(
                          color: isLowStock
                              ? KColors.warning
                              : KColors.textSecondary,
                          fontWeight: isLowStock
                              ? FontWeight.w600
                              : FontWeight.normal,
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
            ],
          ),
          if (!inSelection)
            const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
