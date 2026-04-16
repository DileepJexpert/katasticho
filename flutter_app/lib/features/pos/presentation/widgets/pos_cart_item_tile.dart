import 'package:flutter/material.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_cart_state.dart';

/// Single cart item row with quantity controls and swipe-to-delete.
class PosCartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  const PosCartItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('cart_${item.itemId ?? index}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: KColors.error.withValues(alpha: 0.1),
        child: const Icon(Icons.delete_outline, color: KColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: KTypography.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (item.sku != null)
                    Text(item.sku!,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                ],
              ),
            ),
            KSpacing.hGapSm,

            // Quantity stepper
            _QuantityStepper(
              quantity: item.quantity,
              onChanged: onQuantityChanged,
            ),
            KSpacing.hGapMd,

            // Line total
            SizedBox(
              width: 80,
              child: Text(
                CurrencyFormatter.formatIndian(item.lineTotal),
                style: KTypography.amountSmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: () => onChanged(quantity - 1),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            child: Text(
              quantity == quantity.roundToDouble()
                  ? quantity.toInt().toString()
                  : quantity.toStringAsFixed(1),
              style: KTypography.labelMedium,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
