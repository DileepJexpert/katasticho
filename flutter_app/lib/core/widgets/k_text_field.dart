import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standardized text field with label, prefix, suffix, and validation.
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
    this.selectAllOnFocus = false,
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
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      validator: widget.validator,
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
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefix: widget.prefix,
        suffix: widget.suffix,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: widget.suffixIcon != null
            ? IconButton(
                icon: Icon(widget.suffixIcon),
                onPressed: widget.onSuffixTap,
              )
            : widget.suffix,
        counterText: '',
      ),
    );
  }
}
