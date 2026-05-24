import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/dashboard_config.dart';

/// Dense command tiles for frequent accounting actions.
class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 720
            ? 4
            : width >= 460
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: KSpacing.sm,
            mainAxisSpacing: KSpacing.sm,
            mainAxisExtent: crossAxisCount == 1 ? 54 : 72,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) =>
              _QuickActionBlock(action: actions[index]),
        );
      },
    );
  }
}

class _QuickActionBlock extends StatelessWidget {
  final QuickAction action;

  const _QuickActionBlock({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(KSpacing.radiusMd);

    return Material(
      color: cs.surface,
      borderRadius: br,
      child: InkWell(
        borderRadius: br,
        onTap: () => context.go(action.route),
        splashColor: action.color.withValues(alpha: 0.10),
        highlightColor: action.color.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(action.icon, color: action.color, size: 18),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    action.label,
                    style: KTypography.labelMedium.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
