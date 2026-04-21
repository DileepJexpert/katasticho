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
  final void Function(String unit, String? uomId, double? conversionFactor, double? customPrice)? onUnitChanged;
  final ValueChanged<double>? onDiscountChanged;

  const PosCartItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onUnitChanged,
    this.onDiscountChanged,
  });

  static bool _isBlocked(CartItem item) {
    final t = item.discountThresholds;
    if (t == null) return false;
    final blockAt = (t['blockAt'] as num?)?.toDouble() ?? 100;
    return item.discountPct > blockAt;
  }

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
            // Color dot indicating margin band
            _MarginDot(
              discountPct: item.discountPct,
              thresholds: item.discountThresholds,
            ),
            const SizedBox(width: 8),

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
                  if (item.mrp != null && item.mrp! > 0 && item.mrp != item.rate)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Row(
                        children: [
                          Text(
                            'MRP ${CurrencyFormatter.formatIndian(item.mrp!)}',
                            style: KTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: KColors.textHint,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.batchNumber != null || item.batchExpiry != null)
                    _BatchInfoRow(
                      batchNumber: item.batchNumber,
                      batchExpiry: item.batchExpiry,
                    ),
                  if (item.isWeightBased)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.scale, size: 11, color: KColors.info),
                          const SizedBox(width: 3),
                          Text(
                            '${item.quantity.toStringAsFixed(3)} kg × ${CurrencyFormatter.formatIndian(item.rate)}/kg',
                            style: KTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: KColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.taxAmount > 0)
                    Text(
                      item.isWeightBased
                          ? '${CurrencyFormatter.formatIndian(item.lineTotal)} + tax ${CurrencyFormatter.formatIndian(item.taxAmount)}'
                          : '${CurrencyFormatter.formatIndian(item.rate)} × ${_fmtQty(item.quantity)} + tax ${CurrencyFormatter.formatIndian(item.taxAmount)}',
                      style: KTypography.labelSmall.copyWith(
                        color: KColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  if (_isBlocked(item))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: KColors.error),
                          const SizedBox(width: 3),
                          Text('Cannot sell below cost',
                            style: KTypography.labelSmall.copyWith(
                              fontSize: 10, color: KColors.error, fontWeight: FontWeight.w600,
                            )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            KSpacing.hGapSm,

            // Unit selector (only when multiple selling units available)
            if (item.availableUnits.isNotEmpty && onUnitChanged != null)
              _UnitSelector(
                currentUnit: item.unit ?? '',
                availableUnits: item.availableUnits,
                onUnitChanged: onUnitChanged!,
              ),
            if (item.availableUnits.isNotEmpty && onUnitChanged != null)
              const SizedBox(width: 6),

            // Quantity stepper or weight display
            if (item.isWeightBased)
              _WeightDisplay(
                weightKg: item.quantity,
                onChanged: onQuantityChanged,
              )
            else
              _QuantityStepper(
                quantity: item.quantity,
                onChanged: onQuantityChanged,
              ),
            KSpacing.hGapMd,

            // Discount input
            SizedBox(
              width: 52,
              child: _DiscountField(
                discountPct: item.discountPct,
                onChanged: onDiscountChanged,
                isBlocked: _isBlocked(item),
              ),
            ),
            KSpacing.hGapSm,

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

class _WeightDisplay extends StatelessWidget {
  final double weightKg;
  final ValueChanged<double> onChanged;

  const _WeightDisplay({
    required this.weightKg,
    required this.onChanged,
  });

  void _showWeightEditor(BuildContext context) {
    final controller = TextEditingController(
      text: weightKg.toStringAsFixed(3),
    );
    bool isGrams = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Weight'),
            content: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,3}')),
                    ],
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Weight',
                      border: const OutlineInputBorder(),
                      suffixText: isGrams ? 'gm' : 'kg',
                    ),
                    onSubmitted: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        final kg = isGrams ? parsed / 1000 : parsed;
                        onChanged(kg);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    final currentValue =
                        double.tryParse(controller.text) ?? 0;
                    setDialogState(() {
                      isGrams = !isGrams;
                      if (currentValue > 0) {
                        final converted = isGrams
                            ? currentValue * 1000
                            : currentValue / 1000;
                        controller.text = isGrams
                            ? converted.toStringAsFixed(0)
                            : converted.toStringAsFixed(3);
                      }
                    });
                  },
                  child: Text(isGrams ? 'GM' : 'KG'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(controller.text);
                  if (parsed != null && parsed > 0) {
                    final kg = isGrams ? parsed / 1000 : parsed;
                    onChanged(kg);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _showWeightEditor(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scale, size: 14, color: KColors.info),
            const SizedBox(width: 4),
            Text(
              '${weightKg.toStringAsFixed(3)} kg',
              style: KTypography.labelMedium.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  final String currentUnit;
  final List<Map<String, dynamic>> availableUnits;
  final void Function(String unit, String? uomId, double? conversionFactor, double? customPrice) onUnitChanged;

  const _UnitSelector({
    required this.currentUnit,
    required this.availableUnits,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allUnits = [
      {'abbreviation': currentUnit, 'uomId': null, 'conversionFactor': null, 'customPrice': null},
      ...availableUnits,
    ];
    final seen = <String>{};
    final uniqueUnits = allUnits.where((u) {
      final abbr = (u['abbreviation'] ?? '') as String;
      return abbr.isNotEmpty && seen.add(abbr.toUpperCase());
    }).toList();

    if (uniqueUnits.length < 2) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      position: PopupMenuPosition.under,
      onSelected: (idx) {
        final u = uniqueUnits[idx];
        onUnitChanged(
          u['abbreviation'] as String,
          u['uomId'] as String?,
          (u['conversionFactor'] as num?)?.toDouble(),
          (u['customPrice'] as num?)?.toDouble(),
        );
      },
      itemBuilder: (_) => uniqueUnits.asMap().entries.map((e) {
        final u = e.value;
        final abbr = u['abbreviation'] as String;
        final isSelected = abbr.toUpperCase() == currentUnit.toUpperCase();
        return PopupMenuItem<int>(
          value: e.key,
          child: Text(
            abbr,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? cs.primary : null,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentUnit, style: KTypography.labelSmall),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BatchInfoRow extends StatelessWidget {
  final String? batchNumber;
  final String? batchExpiry;

  const _BatchInfoRow({this.batchNumber, this.batchExpiry});

  @override
  Widget build(BuildContext context) {
    Color expiryColor = KColors.textHint;
    String? expiryLabel;

    if (batchExpiry != null && batchExpiry!.isNotEmpty) {
      final expiry = DateTime.tryParse(batchExpiry!);
      if (expiry != null) {
        final daysUntil = expiry.difference(DateTime.now()).inDays;
        if (daysUntil < 0) {
          expiryColor = KColors.error;
          expiryLabel = 'EXPIRED';
        } else if (daysUntil <= 30) {
          expiryColor = KColors.warning;
          expiryLabel = 'Exp $batchExpiry';
        } else {
          expiryLabel = 'Exp $batchExpiry';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 11, color: expiryColor),
          const SizedBox(width: 3),
          if (batchNumber != null)
            Text(
              batchNumber!,
              style: KTypography.labelSmall
                  .copyWith(fontSize: 10, color: expiryColor),
            ),
          if (batchNumber != null && expiryLabel != null)
            Text(' · ',
                style: KTypography.labelSmall
                    .copyWith(fontSize: 10, color: expiryColor)),
          if (expiryLabel != null)
            Text(
              expiryLabel,
              style: KTypography.labelSmall.copyWith(
                fontSize: 10,
                color: expiryColor,
                fontWeight:
                    expiryColor == KColors.error ? FontWeight.w700 : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _MarginDot extends StatelessWidget {
  final double discountPct;
  final Map<String, dynamic>? thresholds;

  const _MarginDot({required this.discountPct, this.thresholds});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _dotColor(),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _dotColor() {
    if (thresholds == null) return const Color(0xFF22C55E); // green if no data

    final blockAt = (thresholds!['blockAt'] as num?)?.toDouble() ?? 100;
    final redMax = (thresholds!['redMax'] as num?)?.toDouble() ?? 100;
    final yellowMax = (thresholds!['yellowMax'] as num?)?.toDouble() ?? 100;
    final blueMax = (thresholds!['blueMax'] as num?)?.toDouble() ?? 100;

    if (discountPct > blockAt) return const Color(0xFF1F2937);  // Black - LOSS
    if (discountPct > redMax) return const Color(0xFFEF4444);   // Red
    if (discountPct > yellowMax) return const Color(0xFFEAB308); // Yellow
    if (discountPct > blueMax) return const Color(0xFF3B82F6);  // Blue
    return const Color(0xFF22C55E);                              // Green
  }
}

class _DiscountField extends StatelessWidget {
  final double discountPct;
  final ValueChanged<double>? onChanged;
  final bool isBlocked;

  const _DiscountField({
    required this.discountPct,
    this.onChanged,
    this.isBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: TextEditingController(text: discountPct > 0 ? discountPct.toStringAsFixed(0) : ''),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: KTypography.labelSmall.copyWith(
        color: isBlocked ? KColors.error : null,
        fontSize: 11,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        suffixText: '%',
        suffixStyle: KTypography.labelSmall.copyWith(fontSize: 10),
        hintText: '0',
        hintStyle: KTypography.labelSmall.copyWith(color: KColors.textHint, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isBlocked ? KColors.error : cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isBlocked ? KColors.error : cs.outlineVariant),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')),
      ],
      onChanged: (v) {
        final pct = double.tryParse(v) ?? 0;
        onChanged?.call(pct.clamp(0, 99));
      },
    );
  }
}
