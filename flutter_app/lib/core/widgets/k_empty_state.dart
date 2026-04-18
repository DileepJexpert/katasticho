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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: cs.primary,
              ),
            ),
            KSpacing.vGapMd,
            Text(
              title,
              style: KTypography.h3.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              KSpacing.vGapXs,
              Text(
                subtitle!,
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              KSpacing.vGapMd,
              KButton(
                label: actionLabel!,
                onPressed: onAction,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
