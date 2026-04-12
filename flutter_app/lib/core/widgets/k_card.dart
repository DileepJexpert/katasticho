import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Standardized card with optional header, action, and status indicator.
///
/// Theme-aware: pulls surface/border/text colors from `Theme.of(context)` so
/// it adapts automatically to light & dark modes.
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = radius ?? KSpacing.radiusLg;
    final br = BorderRadius.circular(r);

    final defaultShadow = isDark
        ? <BoxShadow>[]
        : const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ];

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(18),
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
                                : cs.onSurface,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: KTypography.bodySmall.copyWith(
                            color: gradient != null
                                ? Colors.white70
                                : cs.onSurfaceVariant,
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
            ? (backgroundColor ?? cs.surface)
            : null,
        gradient: gradient,
        borderRadius: br,
        border: gradient == null
            ? Border.all(
                color: borderColor ?? cs.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              )
            : null,
        boxShadow: shadow ?? defaultShadow,
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
          splashColor: cs.primary.withValues(alpha: 0.08),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// KPI card for dashboard metrics.
///
/// Compact layout (40px tinted icon tile + amount + label) sized to fit
/// inside a 152-158px tall grid tile without overflow.
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
    final cs = Theme.of(context).colorScheme;
    final accent = iconColor ?? cs.primary;
    final tile = backgroundColor ?? accent.withValues(alpha: 0.12);

    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              if (trend != null)
                _TrendPill(trend: trend!, positive: trendPositive == true),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: KTypography.amountLarge.copyWith(
              fontSize: 22,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: KTypography.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    final c = positive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: c,
          ),
          const SizedBox(width: 3),
          Text(
            trend,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
