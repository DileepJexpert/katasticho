import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

class KCollapsibleSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool initiallyExpanded;
  final List<Widget> children;
  final EdgeInsetsGeometry? childrenPadding;

  const KCollapsibleSection({
    super.key,
    required this.title,
    this.icon,
    this.initiallyExpanded = false,
    required this.children,
    this.childrenPadding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: EdgeInsets.zero,
        childrenPadding:
            childrenPadding ?? const EdgeInsets.only(bottom: KSpacing.sm),
        leading: icon != null
            ? Icon(icon, size: 18, color: cs.primary)
            : null,
        title: Text(title, style: KTypography.labelLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
        shape: Border.all(color: Colors.transparent),
        collapsedShape: Border.all(color: Colors.transparent),
        children: children,
      ),
    );
  }
}
