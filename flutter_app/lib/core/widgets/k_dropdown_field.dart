import 'package:flutter/material.dart';
import '../theme/k_typography.dart';

/// Standardized dropdown field matching [KTextField] structure & vertical baseline.
class KDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final bool isRequired;
  final String? hint;
  final String? Function(T?)? validator;

  const KDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.isRequired = false,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLabel = label.isNotEmpty;

    final field = DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      style: KTypography.bodyMedium.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: KTypography.bodyMedium.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: cs.onSurfaceVariant)
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
      ),
    );

    if (!hasLabel) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRequired)
          Text.rich(
            TextSpan(
              text: label,
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
            label,
            style: KTypography.labelLarge.copyWith(color: cs.onSurface),
          ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }
}
