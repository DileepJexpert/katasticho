import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';

/// Standardized text field with label, prefix, suffix, and validation.
class KTextField extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon),
                onPressed: onSuffixTap,
              )
            : suffix,
        counterText: '',
      ),
    );
  }

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
