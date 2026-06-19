import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../routing/app_router.dart';

/// Thin breadcrumb bar for Supply Chain sub-screens: "Supply Chain › {current}".
/// "Supply Chain" taps back to the dashboard hub, so a sub-screen never feels
/// like an orphan module. Drop into an AppBar's `bottom:`.
PreferredSizeWidget scmBreadcrumb(BuildContext context, String current) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(34),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => context.go(Routes.supplyChainDashboard),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, size: 14, color: KColors.primary),
                    const SizedBox(width: 4),
                    Text('Supply Chain',
                        style: TextStyle(
                            color: KColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: KColors.textSecondary),
            const SizedBox(width: 2),
            Text(current,
                style: TextStyle(color: KColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
