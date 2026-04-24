import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/item_repository.dart';

class ReorderScreen extends ConsumerStatefulWidget {
  const ReorderScreen({super.key});

  @override
  ConsumerState<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends ConsumerState<ReorderScreen> {
  String _sortBy = 'urgency';

  @override
  Widget build(BuildContext context) {
    final lowStockAsync = ref.watch(lowStockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: 'Sort by',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'urgency', child: Text('Most urgent')),
              PopupMenuItem(value: 'name', child: Text('Name A-Z')),
              PopupMenuItem(value: 'quantity', child: Text('Lowest stock')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(lowStockProvider),
        child: lowStockAsync.when(
          loading: () => const KLoading(),
          error: (err, _) => KErrorView(
            message: 'Failed to load low stock items: $err',
            onRetry: () => ref.invalidate(lowStockProvider),
          ),
          data: (raw) {
            final content = raw['data'] ?? raw;
            final items = (content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []))
                .cast<Map<String, dynamic>>();

            if (items.isEmpty) {
              return const KEmptyState(
                icon: Icons.check_circle_outline,
                title: 'All items are stocked',
                subtitle: 'No items below their reorder level',
              );
            }

            final sorted = _sortItems(items);

            return Column(
              children: [
                // Summary bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: 10),
                  color: KColors.warning.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: KColors.warning),
                      KSpacing.hGapSm,
                      Text(
                        '${items.length} item${items.length == 1 ? '' : 's'} below reorder level',
                        style: KTypography.labelMedium
                            .copyWith(color: KColors.warning),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) =>
                        _ReorderItemCard(item: sorted[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortItems(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => (a['itemName']?.toString() ?? '')
            .compareTo(b['itemName']?.toString() ?? ''));
      case 'quantity':
        sorted.sort((a, b) {
          final aQty = (a['quantityOnHand'] as num?)?.toDouble() ?? 0;
          final bQty = (b['quantityOnHand'] as num?)?.toDouble() ?? 0;
          return aQty.compareTo(bQty);
        });
      default:
        sorted.sort((a, b) {
          final aQty = (a['quantityOnHand'] as num?)?.toDouble() ?? 0;
          final aReorder = (a['reorderLevel'] as num?)?.toDouble() ?? 1;
          final bQty = (b['quantityOnHand'] as num?)?.toDouble() ?? 0;
          final bReorder = (b['reorderLevel'] as num?)?.toDouble() ?? 1;
          final aRatio = aReorder > 0 ? aQty / aReorder : 1;
          final bRatio = bReorder > 0 ? bQty / bReorder : 1;
          return aRatio.compareTo(bRatio);
        });
    }
    return sorted;
  }
}

class _ReorderItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ReorderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['itemName']?.toString() ??
        item['name']?.toString() ?? 'Item';
    final sku = item['itemSku']?.toString() ??
        item['sku']?.toString() ?? '';
    final onHand = (item['quantityOnHand'] as num?)?.toDouble() ??
        (item['totalOnHand'] as num?)?.toDouble() ?? 0;
    final reorderLevel = (item['reorderLevel'] as num?)?.toDouble() ?? 0;
    final avgCost = (item['averageCost'] as num?)?.toDouble() ?? 0;
    final itemId = item['itemId']?.toString() ?? item['id']?.toString();
    final warehouseName = item['warehouseName']?.toString();
    final isLowStock = item['lowStock'] as bool? ?? true;

    final ratio = reorderLevel > 0 ? onHand / reorderLevel : 1.0;
    final stockColor = ratio <= 0.25
        ? KColors.error
        : ratio <= 0.5
            ? KColors.warning
            : KColors.accent;

    return KCard(
      onTap: itemId != null ? () => context.push('/items/$itemId') : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: stockColor.withValues(alpha: 0.12),
                child: Icon(
                  onHand <= 0
                      ? Icons.error_outline
                      : Icons.inventory_2_outlined,
                  size: 20,
                  color: stockColor,
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: KTypography.labelLarge),
                    Text('SKU: $sku',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                    if (warehouseName != null)
                      Text(warehouseName,
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.textHint)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: KColors.textHint),
            ],
          ),
          KSpacing.vGapSm,
          // Stock level bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: KColors.divider,
              color: stockColor,
              minHeight: 6,
            ),
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              _Metric(
                label: 'On Hand',
                value: _fmt(onHand),
                color: stockColor,
              ),
              KSpacing.hGapMd,
              _Metric(
                label: 'Reorder At',
                value: _fmt(reorderLevel),
              ),
              KSpacing.hGapMd,
              _Metric(
                label: 'Avg Cost',
                value: avgCost > 0
                    ? CurrencyFormatter.formatCompact(avgCost)
                    : '—',
              ),
              KSpacing.hGapMd,
              _Metric(
                label: 'Shortfall',
                value: _fmt((reorderLevel - onHand).clamp(0, double.infinity)),
                color: KColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: KTypography.amountSmall
                  .copyWith(color: color ?? KColors.textPrimary)),
          Text(label, style: KTypography.labelSmall),
        ],
      ),
    );
  }
}
