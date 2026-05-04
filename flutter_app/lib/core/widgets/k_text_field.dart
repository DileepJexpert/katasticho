import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/k_typography.dart';

/// Standardized text field — **Katasticho 2026** spec.
///
/// • Top-aligned static label above the field (13px medium) — no
///   Material floating-label jump.
/// • Field height ~40px (from the old ~56px).
/// • Content padding 12/11 (horizontal/vertical) for single-line.
class KTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final FocusNode? focusNode;
  final String? initialValue;
  final TextInputAction? textInputAction;
  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final bool selectAllOnFocus;
  final bool isRequired;
  final String? serverError;

  const KTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.focusNode,
    this.initialValue,
    this.textInputAction,
    this.onTap,
    this.onFieldSubmitted,
    this.selectAllOnFocus = true,
    this.isRequired = false,
    this.serverError,
  });

  @override
  State<KTextField> createState() => _KTextFieldState();

  /// Convenience factory for amount fields with INR prefix.
  factory KTextField.amount({
    Key? key,
    required String label,
    TextEditingController? controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
    String currencySymbol = '\u20B9',
    bool isRequired = false,
    String? serverError,
  }) {
    return KTextField(
      key: key,
      label: label,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      prefixIcon: Icons.currency_rupee,
      selectAllOnFocus: true,
      isRequired: isRequired,
      serverError: serverError,
    );
  }

  /// Convenience factory for search fields.
  factory KTextField.search({
    Key? key,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    String hint = 'Search...',
    VoidCallback? onClear,
  }) {
    return KTextField(
      key: key,
      label: '',
      hint: hint,
      controller: controller,
      onChanged: onChanged,
      prefixIcon: Icons.search,
      suffixIcon: controller?.text.isNotEmpty == true ? Icons.close : null,
      onSuffixTap: onClear,
    );
  }
}

class _KTextFieldState extends State<KTextField> {
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.selectAllOnFocus) {
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void didUpdateWidget(KTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectAllOnFocus && !widget.selectAllOnFocus) {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    } else if (!oldWidget.selectAllOnFocus && widget.selectAllOnFocus) {
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus &&
        widget.controller != null &&
        widget.controller!.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.controller != null &&
            widget.controller!.text.isNotEmpty) {
          widget.controller!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller!.text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.selectAllOnFocus) {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLabel = widget.label.isNotEmpty;
    final isMultiline = (widget.maxLines ?? 1) > 1;

    String? Function(String?)? effectiveValidator = widget.validator;
    if (widget.serverError != null) {
      final original = widget.validator;
      effectiveValidator = (v) {
        final clientErr = original?.call(v);
        if (clientErr != null) return clientErr;
        return widget.serverError;
      };
    }

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      validator: effectiveValidator,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      focusNode: widget.selectAllOnFocus ? _effectiveFocusNode : widget.focusNode,
      textInputAction: widget.textInputAction,
      onTap: widget.onTap,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: KTypography.bodyMedium.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        // Top-aligned label is rendered above via Column; suppress Material's
        // floating label here.
        hintText: widget.hint,
        hintStyle: KTypography.bodyMedium.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefix: widget.prefix,
        suffix: widget.suffix,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 18, color: cs.onSurfaceVariant)
            : null,
        suffixIcon: widget.suffixIcon != null
            ? IconButton(
                icon: Icon(widget.suffixIcon, size: 18),
                color: cs.onSurfaceVariant,
                onPressed: widget.onSuffixTap,
              )
            : widget.suffix,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isMultiline ? 10 : 11,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );

    if (!hasLabel) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isRequired)
          Text.rich(
            TextSpan(
              text: widget.label,
              style: KTypography.labelLarge.copyWith(color: cs.onSurface),
              children: [
                TextSpan(
                  text: ' *',
                  style: KTypography.labelLarge.copyWith(color: cs.error),
                ),
              ],
            ),
          )
        else
          Text(
            widget.label,
            style: KTypography.labelLarge.copyWith(color: cs.onSurface),
          ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
