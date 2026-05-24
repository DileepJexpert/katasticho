import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/shortbook_repository.dart';

class ShortbookScreen extends ConsumerStatefulWidget {
  const ShortbookScreen({super.key});

  @override
  ConsumerState<ShortbookScreen> createState() => _ShortbookScreenState();
}

class _ShortbookScreenState extends ConsumerState<ShortbookScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final shortbookAsync = ref.watch(shortbookProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shortbook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(shortbookProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shortbookProvider),
        child: shortbookAsync.when(
          loading: () => const KLoading(),
          error: (err, _) => KErrorView(
            message: 'Failed to load shortbook: $err',
            onRetry: () => ref.invalidate(shortbookProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const KEmptyState(
                icon: Icons.check_circle_outline,
                title: 'All stock levels healthy',
                subtitle: 'No items need ordering right now',
              );
            }

            final backorderedCount =
                items.where((i) => i['reason'] == 'BACKORDER').length;
            final lowStockCount =
                items.where((i) => i['reason'] == 'LOW_STOCK').length;
            final bothCount =
                items.where((i) => i['reason'] == 'BOTH').length;

            return Column(
              children: [
                // Summary bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: 10),
                  color: KColors.error.withValues(alpha: 0.07),
                  child: Wrap(
                    spacing: KSpacing.md,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: KColors.error),
                          const SizedBox(width: 6),
                          Text(
                            '${items.length} item${items.length == 1 ? '' : 's'} to order',
                            style: KTypography.labelMedium
                                .copyWith(color: KColors.error),
                          ),
                        ],
                      ),
                      if (backorderedCount > 0)
                        _SummaryChip(
                          label: 'Backordered: $backorderedCount',
                          color: Colors.orange,
                        ),
                      if (lowStockCount > 0)
                        _SummaryChip(
                          label: 'Low Stock: $lowStockCount',
                          color: Colors.amber.shade700,
                        ),
                      if (bothCount > 0)
                        _SummaryChip(
                          label: 'Both: $bothCount',
                          color: KColors.error,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item['itemId']?.toString() ?? '';
                      final isSelected = _selected.contains(itemId);
                      return _ShortbookItemCard(
                        item: item,
                        isSelected: isSelected,
                        onToggle: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(itemId);
                            } else {
                              _selected.add(itemId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.stockReceiptCreate),
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text('Generate GRN (${_selected.length})'),
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _ShortbookItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ShortbookItemCard({
    required this.item,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        item['itemName']?.toString() ?? item['name']?.toString() ?? 'Item';
    final sku = item['sku']?.toString() ?? '';
    final reason = item['reason']?.toString() ?? '';
    final onHand = (item['currentStock'] as num?)?.toDouble() ?? 0;
    final backordered = (item['backordered'] as num?)?.toDouble() ?? 0;
    final orderQty = (item['suggestOrderQty'] as num?)?.toDouble() ?? 0;

    final isBackorder = reason == 'BACKORDER' || reason == 'BOTH';
    final isLowStock = reason == 'LOW_STOCK' || reason == 'BOTH';
    final isBoth = reason == 'BOTH';

    final borderColor = isBoth
        ? KColors.error
        : isBackorder
            ? Colors.orange
            : Colors.amber.shade700;

    return KCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: KTypography.labelLarge),
                        if (sku.isNotEmpty)
                          Text(
                            'SKU: $sku',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  // Reason tags
                  Wrap(
                    spacing: 4,
                    children: [
                      if (isBackorder)
                        _ReasonTag(label: 'Backordered', color: Colors.orange),
                      if (isLowStock)
                        _ReasonTag(
                            label: 'Low Stock', color: Colors.amber.shade700),
                    ],
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Row(
                children: [
                  _Metric(
                    label: 'On Hand',
                    value: _fmt(onHand),
                    color: onHand <= 0 ? KColors.error : KColors.textPrimary,
                  ),
                  KSpacing.hGapMd,
                  _Metric(
                    label: 'Backordered',
                    value: backordered > 0 ? _fmt(backordered) : '—',
                    color: backordered > 0 ? Colors.orange : null,
                  ),
                  KSpacing.hGapMd,
                  _Metric(
                    label: 'Order Qty',
                    value: _fmt(orderQty),
                    color: KColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _ReasonTag extends StatelessWidget {
  final String label;
  final Color color;

  const _ReasonTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }
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
          Text(
            value,
            style: KTypography.amountSmall
                .copyWith(color: color ?? KColors.textPrimary),
          ),
          Text(label, style: KTypography.labelSmall),
        ],
      ),
    );
  }
}
