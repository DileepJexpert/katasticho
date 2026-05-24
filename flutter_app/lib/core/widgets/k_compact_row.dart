import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';

class KCompactRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double spacing;
  final double stackBelow;

  const KCompactRow({
    super.key,
    required this.children,
    this.flex,
    this.spacing = KSpacing.sm,
    this.stackBelow = 640,
  });

  @override
  Widget build(BuildContext context) {
    final flexValues = flex ?? List.filled(children.length, 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(flex: flexValues[i], child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
