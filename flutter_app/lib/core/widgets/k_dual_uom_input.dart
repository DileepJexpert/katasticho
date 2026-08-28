import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../utils/dual_uom_formatter.dart';

/// Keyboard-first dual Unit-of-Measure input widget for wholesale & retail trade.
///
/// Handles rapid counter inputs:
/// - `10.5` or `10/5` -> 10 main packaging units (e.g. Boxes) + 5 sub-units (e.g. Strips).
/// - `.3` or `/3` -> 0 main units + 3 sub-units.
/// - Live helper badge showing breakdown and total calculated base quantity.
class KDualUomInput extends StatefulWidget {
  final double initialQuantity;
  final double conversionFactor;
  final String mainUnit;
  final String? subUnit;
  final ValueChanged<DualUomQuantity> onChanged;
  final ValueChanged<DualUomQuantity>? onSubmitted;
  final String? label;
  final bool autofocus;
  final bool enabled;
  final double? maxQuantity;
  final bool showNudgeButtons;
  final FocusNode? focusNode;

  const KDualUomInput({
    super.key,
    required this.initialQuantity,
    this.conversionFactor = 1.0,
    this.mainUnit = 'PCS',
    this.subUnit,
    required this.onChanged,
    this.onSubmitted,
    this.label,
    this.autofocus = false,
    this.enabled = true,
    this.maxQuantity,
    this.showNudgeButtons = true,
    this.focusNode,
  });

  @override
  State<KDualUomInput> createState() => _KDualUomInputState();
}

class _KDualUomInputState extends State<KDualUomInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late DualUomQuantity _currentQty;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _initQuantity();
  }

  void _initQuantity() {
    final text = DualUomParser.formatInput(
      widget.initialQuantity,
      widget.conversionFactor,
    );
    _controller = TextEditingController(text: text);
    _currentQty = DualUomParser.parse(
      text,
      conversionFactor: widget.conversionFactor,
      mainUnit: widget.mainUnit,
      subUnit: widget.subUnit,
    );
  }

  @override
  void didUpdateWidget(covariant KDualUomInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity ||
        oldWidget.conversionFactor != widget.conversionFactor ||
        oldWidget.mainUnit != widget.mainUnit ||
        oldWidget.subUnit != widget.subUnit) {
      if (!_focusNode.hasFocus) {
        final text = DualUomParser.formatInput(
          widget.initialQuantity,
          widget.conversionFactor,
        );
        _controller.text = text;
        _currentQty = DualUomParser.parse(
          text,
          conversionFactor: widget.conversionFactor,
          mainUnit: widget.mainUnit,
          subUnit: widget.subUnit,
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChange(String val) {
    final parsed = DualUomParser.parse(
      val,
      conversionFactor: widget.conversionFactor,
      mainUnit: widget.mainUnit,
      subUnit: widget.subUnit,
    );
    setState(() => _currentQty = parsed);
    widget.onChanged(parsed);
  }

  void _nudgeBaseQty(double delta) {
    final newBase = (_currentQty.totalBaseQty + delta).clamp(0.0, widget.maxQuantity ?? double.infinity);
    final formatted = DualUomParser.formatInput(newBase, widget.conversionFactor);
    _controller.text = formatted;
    _controller.selection = TextSelection.collapsed(offset: formatted.length);
    _handleTextChange(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDual = _currentQty.isDual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: KTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[0-9./+]*$')),
                ],
                style: KTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  hintText: isDual ? 'e.g. 10.5 or 10/5' : '0.00',
                  suffixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    alignment: Alignment.centerRight,
                    child: Text(
                      isDual
                          ? '${widget.mainUnit} (${widget.conversionFactor.toInt() == widget.conversionFactor ? widget.conversionFactor.toInt() : widget.conversionFactor} ${widget.subUnit})'
                          : widget.mainUnit,
                      style: KTypography.labelSmall.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
                onChanged: _handleTextChange,
                onFieldSubmitted: (v) {
                  final parsed = DualUomParser.parse(
                    v,
                    conversionFactor: widget.conversionFactor,
                    mainUnit: widget.mainUnit,
                    subUnit: widget.subUnit,
                  );
                  if (widget.onSubmitted != null) {
                    widget.onSubmitted!(parsed);
                  }
                },
              ),
            ),
            if (widget.showNudgeButtons && isDual) ...[
              const SizedBox(width: 6),
              // Nudge buttons for rapid +1 main unit / +1 sub unit
              _NudgeButton(
                label: '+1 ${widget.mainUnit}',
                onTap: () => _nudgeBaseQty(widget.conversionFactor),
              ),
              const SizedBox(width: 4),
              _NudgeButton(
                label: '+1 ${widget.subUnit}',
                onTap: () => _nudgeBaseQty(1.0),
              ),
            ],
          ],
        ),
        if (isDual && _currentQty.totalBaseQty > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 12, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  _currentQty.displayText,
                  style: KTypography.labelSmall.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NudgeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
          color: cs.surfaceContainerLow,
        ),
        child: Text(
          label,
          style: KTypography.labelSmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
