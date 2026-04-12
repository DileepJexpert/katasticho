import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../../inventory/data/item_repository.dart';

/// Dashboard tile that surfaces items at or below their reorder level.
/// Hits GET /api/v1/stock/low-stock via [lowStockProvider].
class LowStockWidget extends ConsumerWidget {
  const LowStockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockProvider);

    return KCard(
      title: 'Low Stock',
      action: TextButton(
        onPressed: () => context.go(Routes.items),
        child: const Text('View All'),
      ),
      child: lowStockAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: KShimmerCard(height: 80),
        ),
        error: (err, st) => Text(
          'Failed to load: $err',
          style: KTypography.bodySmall,
        ),
        data: (raw) {
          final content = raw['data'] ?? raw;
          final items = content is List
              ? content
              : (content is Map ? (content['content'] as List?) ?? [] : []);

          if (items.isEmpty) {
            return const KEmptyState(
              icon: Icons.check_circle_outline,
              title: 'All items in stock',
              subtitle: 'No items below reorder level',
            );
          }

          return Column(
            children: [
              for (var i = 0; i < items.length && i < 5; i++) ...[
                if (i > 0) const Divider(height: 1),
                _LowStockTile(row: items[i] as Map<String, dynamic>),
              ],
              if (items.length > 5) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${items.length - 5} more',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _LowStockTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final name = row['itemName']?.toString() ?? row['name']?.toString() ?? 'Item';
    final sku = row['itemSku']?.toString() ?? row['sku']?.toString() ?? '';
    final onHand = (row['quantityOnHand'] as num?)?.toDouble()
        ?? (row['totalOnHand'] as num?)?.toDouble()
        ?? 0;
    final reorder = (row['reorderLevel'] as num?)?.toDouble() ?? 0;
    final itemId = row['itemId']?.toString() ?? row['id']?.toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: KColors.warning.withValues(alpha: 0.15),
        child: const Icon(Icons.inventory_2_outlined,
            size: 16, color: KColors.warning),
      ),
      title: Text(name, style: KTypography.labelMedium),
      subtitle: Text('SKU: $sku', style: KTypography.bodySmall),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_fmt(onHand)} / ${_fmt(reorder)}',
            style: KTypography.amountSmall.copyWith(color: KColors.warning),
          ),
          Text('on hand / reorder', style: KTypography.labelSmall),
        ],
      ),
      onTap: itemId == null ? null : () => context.go('/items/$itemId'),
    );
  }

  static String _fmt(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
