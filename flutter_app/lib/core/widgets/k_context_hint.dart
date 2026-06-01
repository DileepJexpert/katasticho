import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../workflow/workflow_hint_resolver.dart';

class KContextHint extends StatelessWidget {
  final WorkflowHint hint;
  final EdgeInsetsGeometry? margin;

  const KContextHint({
    super.key,
    required this.hint,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(hint.variant);
    final icon = _iconFor(hint.variant);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint.title,
                  style: KTypography.labelLarge.copyWith(color: color),
                ),
                KSpacing.vGapXxs,
                Text(
                  hint.body,
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorFor(WorkflowHintVariant variant) {
    return switch (variant) {
      WorkflowHintVariant.warning => KColors.warning,
      WorkflowHintVariant.success => KColors.accent,
      WorkflowHintVariant.info => KColors.primary,
      WorkflowHintVariant.workflow => KColors.primary,
    };
  }

  static IconData _iconFor(WorkflowHintVariant variant) {
    return switch (variant) {
      WorkflowHintVariant.warning => Icons.warning_amber_rounded,
      WorkflowHintVariant.success => Icons.check_circle_outline,
      WorkflowHintVariant.info => Icons.info_outline,
      WorkflowHintVariant.workflow => Icons.route_outlined,
    };
  }
}
