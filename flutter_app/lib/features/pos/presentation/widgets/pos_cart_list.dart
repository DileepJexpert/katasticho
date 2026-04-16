import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import 'pos_cart_item_tile.dart';

/// Collapsible cart list showing all items in the current POS session.
/// Default: expanded. Tap the header to collapse/expand.
class PosCartList extends ConsumerStatefulWidget {
  const PosCartList({super.key});

  @override
  ConsumerState<PosCartList> createState() => _PosCartListState();
}

class _PosCartListState extends ConsumerState<PosCartList> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);
    final cs = Theme.of(context).colorScheme;

    if (cart.isEmpty) {
      return const KEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Cart is empty',
        subtitle: 'Search and add items to start a sale',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.shopping_cart,
                    size: 18, color: cs.onSurfaceVariant),
                KSpacing.hGapSm,
                Text('Cart', style: KTypography.labelLarge),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cart.itemCount} items · ${cart.totalQuantity} qty',
                    style: KTypography.labelSmall.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (!_expanded)
                  Text(
                    CurrencyFormatter.formatIndian(cart.total),
                    style: KTypography.amountSmall.copyWith(
                      color: cs.primary,
                    ),
                  ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more,
                      size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),

        // Divider
        Divider(height: 1, color: cs.outlineVariant),

        // Cart items (collapsible)
        AnimatedCrossFade(
          firstChild: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return PosCartItemTile(
                item: item,
                index: index,
                onQuantityChanged: (qty) {
                  ref
                      .read(posCartProvider.notifier)
                      .updateQuantity(index, qty);
                },
                onRemove: () {
                  ref.read(posCartProvider.notifier).removeItem(index);
                },
              );
            },
          ),
          secondChild: // Collapsed summary
              Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: cart.items
                  .map((item) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${item.name} ×${_fmtQty(item.quantity)}',
                          style: KTypography.labelSmall,
                        ),
                        backgroundColor:
                            cs.surfaceContainerHighest,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
  }
}
