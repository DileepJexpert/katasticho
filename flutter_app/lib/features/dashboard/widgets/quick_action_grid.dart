import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/dashboard_config.dart';

/// Large card-style quick action blocks (replaces the previous small chips).
///
/// Renders a responsive grid: 2 columns on phones, 4 on desktop. Each tile is
/// a tap target ~110px tall with a tinted icon square, label, and chevron.
class QuickActionGrid extends StatelessWidget {
  final List<QuickAction> actions;

  const QuickActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final crossAxisCount = isDesktop ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: KSpacing.md,
        mainAxisSpacing: KSpacing.md,
        mainAxisExtent: 96,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) =>
          _QuickActionBlock(action: actions[index]),
    );
  }
}

class _QuickActionBlock extends StatelessWidget {
  final QuickAction action;

  const _QuickActionBlock({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(KSpacing.radiusLg);

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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, color: action.color, size: 22),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: Text(
                    action.label,
                    style: KTypography.labelLarge.copyWith(
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
