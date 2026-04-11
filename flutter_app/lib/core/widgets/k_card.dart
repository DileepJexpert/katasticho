import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';

/// Standardized card with optional header, action, and status indicator.
class KCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? elevation;

  const KCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Card(
      elevation: elevation ?? 1,
      margin: margin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: KSpacing.borderRadiusMd,
        side: borderColor != null
            ? BorderSide(color: borderColor!)
            : BorderSide.none,
      ),
      child: Padding(
        padding: padding ?? KSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || action != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  if (action != null) action!,
                ],
              ),
              KSpacing.vGapMd,
            ],
            child,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: KSpacing.borderRadiusMd,
        child: card,
      );
    }
    return card;
  }
}

/// KPI card for dashboard metrics.
class KKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? trend;
  final bool? trendPositive;
  final VoidCallback? onTap;

  const KKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.trend,
    this.trendPositive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (backgroundColor ?? KColors.primaryLight)
                      .withValues(alpha: 0.15),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? KColors.primary,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (trendPositive == true
                            ? KColors.success
                            : KColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendPositive == true
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: trendPositive == true
                            ? KColors.success
                            : KColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: trendPositive == true
                              ? KColors.success
                              : KColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          KSpacing.vGapMd,
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          KSpacing.vGapXs,
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
