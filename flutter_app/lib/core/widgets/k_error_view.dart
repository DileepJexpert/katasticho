import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_button.dart';

/// Error view with retry action.
class KErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const KErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.error),
            KSpacing.vGapMd,
            Text(
              message,
              style: KTypography.bodyLarge.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              KSpacing.vGapLg,
              KButton(
                label: 'Retry',
                onPressed: onRetry,
                icon: Icons.refresh,
                variant: KButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner (e.g., form submission errors).
class KErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const KErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              message,
              style: KTypography.bodySmall.copyWith(color: cs.onErrorContainer),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: cs.onErrorContainer,
            ),
        ],
      ),
    );
  }
}
