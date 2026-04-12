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
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemListProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: KTextField.search(
              controller: _searchController,
              hint: 'Search by SKU or name',
              onChanged: (v) {
                setState(() {
                  _searchQuery = v.trim().isEmpty ? null : v.trim();
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = null);
              },
            ),
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
                      return _ItemCard(item: item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.itemCreate),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
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
        final id = item['id']?.toString();
        if (id != null) context.go('/items/$id');
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              itemType == 'SERVICE' ? Icons.build_outlined : Icons.inventory_2_outlined,
              color: KColors.primary,
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
                      const KStatusChip(status: 'CANCELLED', label: 'Inactive', dense: true),
                    ],
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  'SKU: $sku',
                  style: KTypography.bodySmall,
                ),
                if (trackInventory && onHand != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 14,
                        color: isLowStock ? KColors.warning : KColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${onHand.toStringAsFixed(onHand.truncateToDouble() == onHand ? 0 : 2)} on hand',
                        style: KTypography.bodySmall.copyWith(
                          color: isLowStock ? KColors.warning : KColors.textSecondary,
                          fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (isLowStock) ...[
                        const SizedBox(width: 6),
                        const KStatusChip(status: 'OVERDUE', label: 'Low', dense: true),
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
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
