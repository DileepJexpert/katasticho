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
                allowOverSell: cart.allowNegativeStock,
                onQuantityChanged: item.isFreeItem ? null : (qty) {
                  final maxQty = item.maxSellQuantity;
                  // Bill-freely orgs: no blocking warning — the tile's red
                  // "available" pill is the soft cue and the sale goes through.
                  if (!cart.allowNegativeStock &&
                      item.currentStock > 0 &&
                      qty > maxQty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Only ${_fmtQty(maxQty)} ${item.stockUnitLabel} available for ${item.name}',
                        ),
                        backgroundColor: KColors.error,
                      ),
                    );
                  }
                  ref
                      .read(posCartProvider.notifier)
                      .updateQuantity(index, qty);
                },
                onRemove: () {
                  ref.read(posCartProvider.notifier).removeItem(index);
                },
                onUnitChanged: item.availableUnits.isNotEmpty && !item.isFreeItem
                    ? (unit, uomId, conversionFactor, customPrice) {
                        ref.read(posCartProvider.notifier).changeUnit(
                              index,
                              unit,
                              uomId,
                              conversionFactor,
                              customPrice,
                            );
                      }
                    : null,
                onDiscountChanged: item.isFreeItem ? null : (pct) {
                  ref.read(posCartProvider.notifier).setDiscount(index, pct);
                },
                onPrescriptionTap: item.prescriptionRequired
                    ? () => _editPrescription(context, ref, index, item)
                    : null,
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

  /// Opens a small bottom sheet to set / clear the prescription number on
  /// a cart line. Non-blocking — cashier can dismiss without entering one.
  void _editPrescription(
      BuildContext context, WidgetRef ref, int index, CartItem item) {
    final controller =
        TextEditingController(text: item.prescriptionNumber ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.medical_information_outlined,
                    color: Color(0xFFB71C1C), size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Prescription for ${item.name}',
                        style: KTypography.h3)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Prescription No.',
                  hintText: 'Enter Rx number (optional)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (val) {
                  ref
                      .read(posCartProvider.notifier)
                      .setPrescriptionNumber(index, val);
                  Navigator.pop(sheetCtx);
                },
              ),
              const SizedBox(height: 12),
              Text(
                  'You can leave this empty — it can be filled later, or never if the customer is a regular.',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref
                          .read(posCartProvider.notifier)
                          .setPrescriptionNumber(index, null);
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(posCartProvider.notifier)
                          .setPrescriptionNumber(index, controller.text);
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
