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
  final ValueChanged<double>? onQuantityChanged;
  final VoidCallback onRemove;
  final void Function(String unit, String? uomId, double? conversionFactor,
      double? customPrice)? onUnitChanged;
  final ValueChanged<double>? onDiscountChanged;

  const PosCartItemTile({
    super.key,
    required this.item,
    required this.index,
    this.onQuantityChanged,
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

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: KTypography.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isFreeItem)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: _InfoPill(
                            label: 'FREE',
                            icon: Icons.redeem_outlined,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: _metaPills(),
                  ),
                  if (_isBlocked(item))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 12, color: KColors.error),
                          const SizedBox(width: 3),
                          Text(
                            'Cannot sell below cost',
                            style: KTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: KColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

            // Quantity stepper or weight display (disabled for free items)
            if (item.isFreeItem)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('FREE ×${_fmtQty(item.quantity)}',
                    style: KTypography.labelSmall.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w800,
                    )),
              )
            else if (item.isWeightBased && onQuantityChanged != null)
              _WeightDisplay(
                weightKg: item.quantity,
                maxWeightKg: item.maxSellQuantity,
                onChanged: onQuantityChanged!,
              )
            else if (onQuantityChanged != null)
              _QuantityStepper(
                quantity: item.quantity,
                maxQuantity: item.maxSellQuantity,
                unit: item.stockUnitLabel,
                onChanged: onQuantityChanged!,
              ),
            KSpacing.hGapMd,

            // Discount input (hidden for free items)
            if (!item.isFreeItem)
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
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
  }

  List<Widget> _metaPills() {
    final pills = <Widget>[];

    if (item.sku != null && item.sku!.isNotEmpty) {
      pills.add(_InfoPill(label: item.sku!));
    }
    if (item.taxGroupName != null && item.taxGroupName!.isNotEmpty) {
      pills.add(_InfoPill(label: item.taxGroupName!, color: KColors.info));
    }
    if (item.manufacturer != null && item.manufacturer!.isNotEmpty) {
      pills.add(_InfoPill(
        label: item.manufacturer!,
        icon: Icons.business_outlined,
        maxWidth: 150,
      ));
    }
    if (item.composition != null && item.composition!.isNotEmpty) {
      pills.add(_InfoPill(
        label: item.composition!,
        icon: Icons.science_outlined,
        maxWidth: 180,
      ));
    }
    if (item.mrp != null && item.mrp! > 0 && item.mrp != item.rate) {
      pills.add(_InfoPill(
        label: 'MRP ${CurrencyFormatter.formatIndian(item.mrp!)}',
        color: KColors.textHint,
        strikeThrough: true,
      ));
    }
    if (item.batchNumber != null && item.batchNumber!.isNotEmpty) {
      pills.add(_InfoPill(
        label: item.batchNumber!,
        icon: Icons.biotech_outlined,
        color: _batchExpiryColor(),
      ));
    }
    if (item.batchExpiry != null && item.batchExpiry!.isNotEmpty) {
      pills.add(_InfoPill(
        label: _batchExpiryLabel(),
        color: _batchExpiryColor(),
      ));
    }
    pills.add(_InfoPill(
      label:
          '${_fmtQty(item.maxSellQuantity)} ${item.stockUnitLabel} available',
      color: item.exceedsStock ? KColors.error : KColors.textHint,
      icon: Icons.inventory_2_outlined,
      emphasis: item.exceedsStock,
    ));
    if (item.isWeightBased) {
      pills.add(_InfoPill(
        label:
            '${item.quantity.toStringAsFixed(3)} kg x ${CurrencyFormatter.formatIndian(item.rate)}/kg',
        icon: Icons.scale,
        color: KColors.info,
      ));
    }
    if (item.taxAmount > 0) {
      pills.add(_InfoPill(
        label: item.isWeightBased
            ? '${CurrencyFormatter.formatIndian(item.lineTotal)} incl. tax ${CurrencyFormatter.formatIndian(item.taxAmount)}'
            : '${CurrencyFormatter.formatIndian(item.rate)} x ${_fmtQty(item.quantity)} incl. tax ${CurrencyFormatter.formatIndian(item.taxAmount)}',
        color: KColors.textHint,
        maxWidth: 220,
      ));
    }

    return pills;
  }

  Color _batchExpiryColor() {
    final expiry = DateTime.tryParse(item.batchExpiry ?? '');
    if (expiry == null) return KColors.textHint;
    final daysUntil = expiry.difference(DateTime.now()).inDays;
    if (daysUntil < 0) return KColors.error;
    if (daysUntil <= 30) return KColors.warning;
    return KColors.textHint;
  }

  String _batchExpiryLabel() {
    final expiry = DateTime.tryParse(item.batchExpiry ?? '');
    if (expiry == null) return 'Exp ${item.batchExpiry}';
    if (expiry.difference(DateTime.now()).inDays < 0) return 'EXPIRED';
    return 'Exp ${item.batchExpiry}';
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool emphasis;
  final bool strikeThrough;
  final double? maxWidth;

  const _InfoPill({
    required this.label,
    this.icon,
    this.color,
    this.emphasis = false,
    this.strikeThrough = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? KColors.textSecondary;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: resolvedColor),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KTypography.labelSmall.copyWith(
                color: resolvedColor,
                fontSize: 10,
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
                decoration: strikeThrough ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double quantity;
  final double maxQuantity;
  final String unit;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.unit,
    required this.onChanged,
  });

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  void _showQtyEditor(BuildContext context) {
    final controller = TextEditingController(
      text: quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorText;
        return AlertDialog(
          title: const Text('Enter Quantity'),
          content: StatefulBuilder(
            builder: (ctx, setDialogState) => TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Quantity',
                helperText: 'Available: ${_fmtQty(maxQuantity)} $unit',
                errorText: errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final qty = double.tryParse(value);
                if (qty == null || qty <= 0) {
                  setDialogState(() => errorText = 'Enter a valid quantity');
                  return;
                }
                if (maxQuantity > 0 && qty > maxQuantity) {
                  setDialogState(() => errorText =
                      'Only ${_fmtQty(maxQuantity)} $unit available');
                  return;
                }
                onChanged(qty);
                Navigator.pop(ctx);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(controller.text);
                if (qty == null || qty <= 0) {
                  return;
                }
                if (maxQuantity > 0 && qty > maxQuantity) {
                  onChanged(maxQuantity);
                } else {
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
            onTap: maxQuantity > 0 && quantity >= maxQuantity
                ? null
                : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

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
  final double maxWeightKg;
  final ValueChanged<double> onChanged;

  const _WeightDisplay({
    required this.weightKg,
    required this.maxWeightKg,
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
                        onChanged(maxWeightKg > 0 && kg > maxWeightKg
                            ? maxWeightKg
                            : kg);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    final currentValue = double.tryParse(controller.text) ?? 0;
                    setDialogState(() {
                      isGrams = !isGrams;
                      if (currentValue > 0) {
                        final converted =
                            isGrams ? currentValue * 1000 : currentValue / 1000;
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
                    onChanged(
                        maxWeightKg > 0 && kg > maxWeightKg ? maxWeightKg : kg);
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
  final void Function(String unit, String? uomId, double? conversionFactor,
      double? customPrice) onUnitChanged;

  const _UnitSelector({
    required this.currentUnit,
    required this.availableUnits,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allUnits = [
      {
        'abbreviation': currentUnit,
        'uomId': null,
        'conversionFactor': null,
        'customPrice': null
      },
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

    if (discountPct > blockAt) return const Color(0xFF1F2937); // Black - LOSS
    if (discountPct > redMax) return const Color(0xFFEF4444); // Red
    if (discountPct > yellowMax) return const Color(0xFFEAB308); // Yellow
    if (discountPct > blueMax) return const Color(0xFF3B82F6); // Blue
    return const Color(0xFF22C55E); // Green
  }
}

class _DiscountField extends StatefulWidget {
  final double discountPct;
  final ValueChanged<double>? onChanged;
  final bool isBlocked;

  const _DiscountField({
    required this.discountPct,
    this.onChanged,
    this.isBlocked = false,
  });

  @override
  State<_DiscountField> createState() => _DiscountFieldState();
}

class _DiscountFieldState extends State<_DiscountField> {
  late final TextEditingController _ctrl;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.discountPct > 0 ? widget.discountPct.toStringAsFixed(0) : '',
    );
  }

  @override
  void didUpdateWidget(_DiscountField old) {
    super.didUpdateWidget(old);
    if (!_hasFocus && old.discountPct != widget.discountPct) {
      _ctrl.text =
          widget.discountPct > 0 ? widget.discountPct.toStringAsFixed(0) : '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Focus(
      onFocusChange: (focused) => _hasFocus = focused,
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: KTypography.labelSmall.copyWith(
          color: widget.isBlocked ? KColors.error : null,
          fontSize: 11,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          suffixText: '%',
          suffixStyle: KTypography.labelSmall.copyWith(fontSize: 10),
          hintText: '0',
          hintStyle: KTypography.labelSmall
              .copyWith(color: KColors.textHint, fontSize: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
                color: widget.isBlocked ? KColors.error : cs.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
                color: widget.isBlocked ? KColors.error : cs.outlineVariant),
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')),
        ],
        onChanged: (v) {
          final pct = double.tryParse(v) ?? 0;
          widget.onChanged?.call(pct.clamp(0, 99));
        },
      ),
    );
  }
}
