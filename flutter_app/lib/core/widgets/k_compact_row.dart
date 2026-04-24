import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';

class KCompactRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double spacing;

  const KCompactRow({
    super.key,
    required this.children,
    this.flex,
    this.spacing = KSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final flexValues = flex ?? List.filled(children.length, 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(flex: flexValues[i], child: children[i]),
        ],
      ],
    );
  }
}
