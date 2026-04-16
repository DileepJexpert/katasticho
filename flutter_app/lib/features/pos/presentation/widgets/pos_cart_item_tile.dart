import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_cart_state.dart';

/// Single cart item row with quantity controls and swipe-to-delete.
/// Tap the quantity number to type an exact value.
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.sku != null)
                        Text(item.sku!,
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                      if (item.taxGroupName != null &&
                          item.taxGroupName!.isNotEmpty) ...[
                        if (item.sku != null) const SizedBox(width: 6),
                        Text(
                          item.taxGroupName!,
                          style: KTypography.labelSmall.copyWith(
                            color: KColors.info,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.taxAmount > 0)
                    Text(
                      '${CurrencyFormatter.formatIndian(item.rate)} × ${_fmtQty(item.quantity)} + tax ${CurrencyFormatter.formatIndian(item.taxAmount)}',
                      style: KTypography.labelSmall.copyWith(
                        color: KColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            KSpacing.hGapSm,

            // Quantity stepper with tappable number
            _QuantityStepper(
              quantity: item.quantity,
              onChanged: onQuantityChanged,
            ),
            KSpacing.hGapMd,

            // Line total (with tax)
            SizedBox(
              width: 80,
              child: Text(
                CurrencyFormatter.formatIndian(item.lineTotalWithTax),
                style: KTypography.amountSmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
  }
}

class _QuantityStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  void _showQtyEditor(BuildContext context) {
    final controller = TextEditingController(
      text: quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter Quantity'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final qty = double.tryParse(value);
              if (qty != null && qty > 0) {
                onChanged(qty);
              }
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(controller.text);
                if (qty != null && qty > 0) {
                  onChanged(qty);
                }
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

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
          // Tappable quantity — tap to type exact value
          GestureDetector(
            onTap: () => _showQtyEditor(context),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: Text(
                quantity == quantity.roundToDouble()
                    ? quantity.toInt().toString()
                    : quantity.toStringAsFixed(1),
                style: KTypography.labelMedium.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
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
