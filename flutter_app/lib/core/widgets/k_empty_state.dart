import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_button.dart';

/// Empty state placeholder with icon, title, subtitle, and optional action.
class KEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
              ),
              child: Icon(
                icon,
                size: 22,
                color: cs.primary,
              ),
            ),
            KSpacing.vGapSm,
            Text(
              title,
              style: KTypography.h4.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              KSpacing.vGapXxs,
              Text(
                subtitle!,
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              KSpacing.vGapSm,
              KButton(
                label: actionLabel!,
                onPressed: onAction,
                size: KButtonSize.small,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
