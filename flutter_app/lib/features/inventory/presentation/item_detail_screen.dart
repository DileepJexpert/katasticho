import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/item_repository.dart';
import 'item_create_screen.dart';
import 'stock_adjust_sheet.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final data = itemAsync.value;
              if (data == null) return;
              final item = (data['data'] ?? data) as Map<String, dynamic>;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ItemCreateScreen(itemId: itemId, initial: item),
                ),
              );
              ref.invalidate(itemDetailProvider(itemId));
              ref.invalidate(itemListProvider);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete item?'),
                    content: const Text(
                        'This will mark the item inactive. Items with stock on hand cannot be deleted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await ref.read(itemRepositoryProvider).deleteItem(itemId);
                  ref.invalidate(itemListProvider);
                  if (context.mounted) context.pop();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const KLoading(),
        error: (err, st) {
          debugPrint('[ItemDetailScreen] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load item',
            onRetry: () => ref.invalidate(itemDetailProvider(itemId)),
          );
        },
        data: (raw) {
          final item = (raw['data'] ?? raw) as Map<String, dynamic>;
          return _ItemDetailBody(item: item, itemId: itemId);
        },
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String itemId;

  const _ItemDetailBody({required this.item, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item['name']?.toString() ?? 'Item';
    final sku = item['sku']?.toString() ?? '';
    final itemType = item['itemType']?.toString() ?? 'GOODS';
    final trackInventory = item['trackInventory'] as bool? ?? true;
    final onHand = (item['totalOnHand'] as num?)?.toDouble() ?? 0;
    final reorderLevel = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
    final isLowStock = trackInventory && reorderLevel > 0 && onHand <= reorderLevel;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(itemDetailProvider(itemId));
      },
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: KColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    itemType == 'SERVICE' ? Icons.build : Icons.inventory_2,
                    size: 36,
                    color: KColors.primary,
                  ),
                ),
                KSpacing.vGapSm,
                Text(name, style: KTypography.h1, textAlign: TextAlign.center),
                Text('SKU: $sku', style: KTypography.bodySmall),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Stock summary
          if (trackInventory) ...[
            KCard(
              title: 'Stock',
              action: KButton(
                label: 'Adjust',
                icon: Icons.tune,
                variant: KButtonVariant.outlined,
                size: KButtonSize.small,
                onPressed: () => _openAdjustSheet(context, ref),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('On Hand', style: KTypography.labelSmall),
                          KSpacing.vGapXs,
                          Text(
                            _fmtQty(onHand),
                            style: KTypography.h2.copyWith(
                              color: isLowStock ? KColors.warning : null,
                            ),
                          ),
                        ],
                      ),
                      if (isLowStock)
                        const KStatusChip(status: 'OVERDUE', label: 'Low stock'),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KDetailRow(
                    label: 'Reorder Level',
                    value: _fmtQty(reorderLevel),
                  ),
                  KDetailRow(
                    label: 'Reorder Qty',
                    value: _fmtQty((item['reorderQuantity'] as num?)?.toDouble() ?? 0),
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
          ],

          // Pricing
          KCard(
            title: 'Pricing',
            child: Column(
              children: [
                KDetailRow(
                  label: 'Sale Price',
                  value: CurrencyFormatter.formatIndian(
                    (item['salePrice'] as num?)?.toDouble() ?? 0,
                  ),
                ),
                KDetailRow(
                  label: 'Purchase Price',
                  value: CurrencyFormatter.formatIndian(
                    (item['purchasePrice'] as num?)?.toDouble() ?? 0,
                  ),
                ),
                KDetailRow(
                  label: 'GST Rate',
                  value: '${(item['gstRate'] as num?)?.toString() ?? '0'}%',
                ),
                KDetailRow(
                  label: 'HSN Code',
                  value: item['hsnCode']?.toString() ?? '--',
                ),
                KDetailRow(
                  label: 'Unit',
                  value: item['unitOfMeasure']?.toString() ?? 'PCS',
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Movements (FutureBuilder, lazy load)
          if (trackInventory) ...[
            Text('Recent Movements', style: KTypography.h3),
            KSpacing.vGapSm,
            _MovementsList(itemId: itemId),
          ],
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  void _openAdjustSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockAdjustSheet(
        itemId: itemId,
        itemName: item['name']?.toString() ?? 'Item',
        onSaved: () {
          ref.invalidate(itemDetailProvider(itemId));
          ref.invalidate(itemListProvider);
        },
      ),
    );
  }

  static String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2);
  }
}

class _MovementsList extends ConsumerWidget {
  final String itemId;
  const _MovementsList({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(itemRepositoryProvider).getItemMovements(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: KShimmerCard(height: 120),
          );
        }
        if (snapshot.hasError) {
          return KCard(
            child: Text(
              'Failed to load movements: ${snapshot.error}',
              style: KTypography.bodySmall,
            ),
          );
        }
        final raw = snapshot.data;
        final content = raw == null ? null : (raw['data'] ?? raw);
        final movements = content is List
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

        if (movements.isEmpty) {
          return KCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No stock movements yet',
                  style: KTypography.bodySmall,
                ),
              ),
            ),
          );
        }
        return KCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < movements.length && i < 20; i++) ...[
                if (i > 0) const Divider(height: 1),
                _MovementTile(movement: movements[i] as Map<String, dynamic>),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  final Map<String, dynamic> movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final type = movement['movementType']?.toString() ?? '';
    final qty = (movement['quantity'] as num?)?.toDouble() ?? 0;
    final date = movement['movementDate']?.toString() ?? '';
    final note = movement['notes']?.toString() ?? '';
    final reversed = movement['reversed'] as bool? ?? false;
    final isPositive = qty > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isPositive ? KColors.success : KColors.error)
            .withValues(alpha: 0.15),
        child: Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: isPositive ? KColors.success : KColors.error,
        ),
      ),
      title: Text(
        type.replaceAll('_', ' '),
        style: KTypography.labelMedium.copyWith(
          decoration: reversed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        [date, if (note.isNotEmpty) note].join(' • '),
        style: KTypography.bodySmall,
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${qty.toStringAsFixed(qty == qty.truncateToDouble() ? 0 : 2)}',
        style: KTypography.amountSmall.copyWith(
          color: isPositive ? KColors.success : KColors.error,
        ),
      ),
    );
  }
}
