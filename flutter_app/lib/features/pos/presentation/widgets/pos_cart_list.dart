import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import 'pos_cart_item_tile.dart';

/// Collapsible cart list showing all items in the current POS session.
class PosCartList extends ConsumerWidget {
  const PosCartList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, size: 18),
              KSpacing.hGapSm,
              Text('Cart (${cart.itemCount} items)',
                  style: KTypography.labelLarge),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            final item = cart.items[index];
            return PosCartItemTile(
              item: item,
              index: index,
              onQuantityChanged: (qty) {
                ref.read(posCartProvider.notifier).updateQuantity(index, qty);
              },
              onRemove: () {
                ref.read(posCartProvider.notifier).removeItem(index);
              },
            );
          },
        ),
      ],
    );
  }
}
