import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: KColors.error),
            KSpacing.vGapMd,
            Text(
              message,
              style: KTypography.bodyLarge.copyWith(color: KColors.textSecondary),
              textAlign: TextAlign.center,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KColors.errorLight,
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: KColors.error, size: 20),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              message,
              style: KTypography.bodySmall.copyWith(color: KColors.error),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
