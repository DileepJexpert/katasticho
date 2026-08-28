import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../routing/app_router.dart';

/// Breadcrumb bar for Supply Chain sub-screens: "Supply Chain › {current}".
/// Links back to the dashboard hub.
PreferredSizeWidget scmBreadcrumb(BuildContext context, String current) {
  final cs = Theme.of(context).colorScheme;

  return PreferredSize(
    preferredSize: const Size.fromHeight(36),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpacing.md, 0, KSpacing.md, KSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              child: InkWell(
                onTap: () => context.go(Routes.supplyChainDashboard),
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_outlined, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Supply Chain',
                        style: KTypography.labelSmall.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text(
              current,
              style: KTypography.labelSmall.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
