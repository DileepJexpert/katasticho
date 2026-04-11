import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/dashboard_config.dart';

class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KSpacing.sm,
      runSpacing: KSpacing.sm,
      children: actions.map((action) => _QuickActionChip(action: action)).toList(),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final QuickAction action;

  const _QuickActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(action.icon, size: 18, color: action.color),
      label: Text(
        action.label,
        style: KTypography.labelMedium.copyWith(color: KColors.textPrimary),
      ),
      backgroundColor: action.color.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      onPressed: () => context.go(action.route),
    );
  }
}
