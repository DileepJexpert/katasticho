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
  final VoidCallback? onLongPress;
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
    this.onLongPress,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.shadow,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = radius ?? KSpacing.radiusLg;
    final br = BorderRadius.circular(r);

    // Katasticho 2026: borders over shadows. Shadows reserved for floating
    // surfaces (dialogs, menus) via the caller passing an explicit `shadow`.
    const defaultShadow = <BoxShadow>[];

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(KSpacing.md),
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
                color: borderColor ?? cs.outlineVariant,
                width: 1,
              )
            : null,
        boxShadow: shadow ?? defaultShadow,
      ),
      child: content,
    );

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
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

/// KPI card for dashboard metrics — **Katasticho 2026** spec.
///
/// Compact tile layout: tinted icon + value + label, with an optional
/// trend pill in the top-right and an optional sparkline slot at the
/// bottom (e.g. a tiny line chart for the last 7 days).
class KKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? trend;
  final bool? trendPositive;
  final Widget? sparkline;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool expanded;

  const KKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.trend,
    this.trendPositive,
    this.sparkline,
    this.onTap,
    this.showChevron = false,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = iconColor ?? cs.primary;
    final tile = backgroundColor ?? accent.withValues(alpha: 0.10);

    // NOTE: fixed-height SizedBox gaps (not Spacer). KCard wraps us in a
    // Column(mainAxisSize: min) which forwards unbounded height; Spacer
    // there throws "non-zero flex with unbounded height".
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const Spacer(), // OK: Row has bounded width from grid tile
              if (trend != null)
                _TrendPill(trend: trend!, positive: trendPositive == true),
              if (showChevron) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: KTypography.h1.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: KTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sparkline != null) ...[
            const SizedBox(height: 8),
            SizedBox(height: 24, child: sparkline),
          ],
        ],
      ),
    );
  }
}

/// Tiny inline sparkline — pass a list of values (any range, we normalize)
/// and an optional accent color. Renders as a smooth polyline; intended for
/// use inside [KKpiCard.sparkline].
class KSparkline extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double strokeWidth;
  final bool fill;

  const KSparkline({
    super.key,
    required this.values,
    this.color,
    this.strokeWidth = 1.5,
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    if (values.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      painter: _SparklinePainter(
        values: values,
        color: c,
        strokeWidth: strokeWidth,
        fill: fill,
      ),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool fill;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.fill != fill;
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
