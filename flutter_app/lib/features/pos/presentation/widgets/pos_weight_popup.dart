import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Shows the weight input popup for weight-based items.
/// Returns the weight in KG, or null if cancelled.
Future<double?> showWeightPopup(
  BuildContext context, {
  required String itemName,
  required double ratePerKg,
}) {
  return showDialog<double>(
    context: context,
    builder: (ctx) => _WeightPopupDialog(
      itemName: itemName,
      ratePerKg: ratePerKg,
    ),
  );
}

class _WeightPopupDialog extends StatefulWidget {
  final String itemName;
  final double ratePerKg;

  const _WeightPopupDialog({
    required this.itemName,
    required this.ratePerKg,
  });

  @override
  State<_WeightPopupDialog> createState() => _WeightPopupDialogState();
}

class _WeightPopupDialogState extends State<_WeightPopupDialog> {
  final _controller = TextEditingController();
  bool _isGrams = false;
  double _weightKg = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onWeightChanged(String value) {
    final parsed = double.tryParse(value) ?? 0;
    setState(() {
      _weightKg = _isGrams ? parsed / 1000 : parsed;
    });
  }

  void _toggleUnit() {
    final currentText = _controller.text;
    final currentValue = double.tryParse(currentText) ?? 0;
    setState(() {
      _isGrams = !_isGrams;
      if (currentValue > 0) {
        final converted = _isGrams ? currentValue * 1000 : currentValue / 1000;
        _controller.text = _isGrams
            ? converted.toStringAsFixed(0)
            : converted.toStringAsFixed(3);
        _weightKg = _isGrams ? converted / 1000 : converted;
      }
    });
  }

  void _submit() {
    if (_weightKg > 0) {
      Navigator.pop(context, _weightKg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.ratePerKg * _weightKg;
    final unitLabel = _isGrams ? 'gm' : 'kg';

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.scale, size: 20, color: KColors.primary),
              const SizedBox(width: 8),
              const Text('Enter Weight'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.itemName,
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.06),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Rate: ', style: KTypography.bodySmall),
                Text(
                  '${CurrencyFormatter.formatIndian(widget.ratePerKg)}/kg',
                  style: KTypography.labelLarge.copyWith(color: KColors.primary),
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
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
                    suffixText: unitLabel,
                  ),
                  onChanged: _onWeightChanged,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _toggleUnit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                ),
                child: Text(_isGrams ? 'GM' : 'KG'),
              ),
            ],
          ),
          KSpacing.vGapMd,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: _weightKg > 0
                  ? KColors.success.withValues(alpha: 0.08)
                  : KColors.surface,
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(
                color: _weightKg > 0
                    ? KColors.success.withValues(alpha: 0.3)
                    : KColors.divider,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${_weightKg.toStringAsFixed(3)} kg',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatIndian(amount),
                  style: KTypography.amountLarge.copyWith(
                    color: _weightKg > 0 ? KColors.success : KColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [0.25, 0.5, 1.0, 2.0, 5.0].map((kg) {
              final label =
                  kg < 1 ? '${(kg * 1000).toInt()}g' : '${kg.toStringAsFixed(0)}kg';
              return ActionChip(
                label: Text(label),
                onPressed: () {
                  final display = _isGrams
                      ? (kg * 1000).toStringAsFixed(0)
                      : kg.toStringAsFixed(kg < 1 ? 3 : 1);
                  _controller.text = display;
                  _onWeightChanged(display);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _weightKg > 0 ? _submit : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
