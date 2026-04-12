import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Standardized card with optional header, action, and status indicator.
///
/// Modern look: hairline border, soft layered shadow, generous radius.
/// Drops Material's default elevation in favour of an explicit BoxShadow
/// so the card sits flat on tinted backgrounds.
class KCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget? leading;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final double? radius;

  const KCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.leading,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.shadow,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? KSpacing.radiusLg;
    final br = BorderRadius.circular(r);

    final content = Padding(
      padding: padding ?? KSpacing.cardPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || subtitle != null || action != null || leading != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  KSpacing.hGapSm,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: KTypography.h4.copyWith(
                            color: gradient != null
                                ? Colors.white
                                : KColors.textPrimary,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: KTypography.bodySmall.copyWith(
                            color: gradient != null
                                ? Colors.white70
                                : KColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
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
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? KColors.surface)
            : null,
        gradient: gradient,
        borderRadius: br,
        border: gradient == null
            ? Border.all(
                color: borderColor ?? KColors.dividerSoft,
                width: 1,
              )
            : null,
        boxShadow: shadow ?? KSpacing.shadowSm,
      ),
      child: content,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: KColors.primarySoft,
          highlightColor: KColors.primarySoft.withValues(alpha: 0.5),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// KPI card for dashboard metrics.
///
/// Big number, icon tile in tinted soft color, optional trend pill.
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
    final accent = iconColor ?? KColors.primary;
    final tile = backgroundColor ?? accent.withValues(alpha: 0.12);

    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              if (trend != null) _TrendPill(trend: trend!, positive: trendPositive == true),
            ],
          ),
          KSpacing.vGapLg,
          Text(
            value,
            style: KTypography.amountLarge.copyWith(fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: KTypography.labelMedium.copyWith(
              color: KColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  final String trend;
  final bool positive;
  const _TrendPill({required this.trend, required this.positive});

  @override
  Widget build(BuildContext context) {
    final c = positive ? KColors.success : KColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: KSpacing.borderRadiusXl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: c,
          ),
          const SizedBox(width: 3),
          Text(
            trend,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
