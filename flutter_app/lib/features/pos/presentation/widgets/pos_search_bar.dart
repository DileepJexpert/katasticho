import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';

/// Sticky top search bar for POS — searches items or scans barcode.
/// Supports Enter key to add first result instantly.
class PosSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: KTextField(
        label: '',
        hint: 'Search items or scan barcode',
        controller: controller,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        prefixIcon: Icons.search,
        suffixIcon:
            controller.text.isNotEmpty ? Icons.close : null,
        onSuffixTap: onClear,
        focusNode: focusNode,
      ),
    );
  }
}
