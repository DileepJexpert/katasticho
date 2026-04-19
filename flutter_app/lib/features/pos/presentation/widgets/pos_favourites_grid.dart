import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_favourites.dart';
import '../../data/pos_providers.dart';

/// Quick-tap grid of favourite items shown when the cart is empty.
class PosFavouritesGrid extends ConsumerWidget {
  final void Function(Map<String, dynamic> item) onItemTap;

  const PosFavouritesGrid({super.key, required this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favouriteIds = ref.watch(posFavouritesProvider);
    if (favouriteIds.isEmpty) return const SizedBox.shrink();

    final searchResults = ref.watch(posFavouriteItemsProvider);

    return searchResults.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: KColors.warning),
                  KSpacing.hGapXs,
                  Text('Favourites', style: KTypography.labelMedium),
                ],
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) => _FavouriteChip(
                  item: item,
                  onTap: () => onItemTap(item),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FavouriteChip extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _FavouriteChip({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['name'] as String? ?? 'Item';
    final rate = (item['rate'] as num?)?.toDouble() ?? 0;
    final stock = (item['currentStock'] as num?)?.toDouble() ?? 0;
    final inStock = stock > 0;

    return Material(
      color: inStock
          ? cs.surfaceContainerHighest
          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: inStock ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: KTypography.labelSmall.copyWith(
                  color: inStock ? null : KColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatIndian(rate),
                style: KTypography.bodySmall.copyWith(
                  color: inStock ? cs.primary : KColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!inStock)
                Text(
                  'Out of stock',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.error,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
