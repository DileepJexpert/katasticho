import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

class KDocumentHeaderMetric {
  final String label;
  final String value;
  final IconData? icon;

  const KDocumentHeaderMetric({
    required this.label,
    required this.value,
    this.icon,
  });
}

class KDocumentHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget status;
  final String? amount;
  final IconData? icon;
  final List<KDocumentHeaderMetric> metrics;

  const KDocumentHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.amount,
    this.icon,
    this.metrics = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      color: KColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final titleBlock = Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Icon(icon, size: 18, color: cs.primary),
                ),
                KSpacing.hGapSm,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: KTypography.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        KSpacing.hGapSm,
                        status,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final amountText = amount == null
              ? null
              : Text(
                  amount!,
                  style: KTypography.amountMedium,
                  textAlign: compact ? TextAlign.start : TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );

          final metricRow = metrics.isEmpty
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < metrics.length; i++) ...[
                        if (i > 0) KSpacing.hGapSm,
                        _HeaderMetric(metric: metrics[i]),
                      ],
                    ],
                  ),
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                if (amountText != null) ...[
                  KSpacing.vGapXs,
                  amountText,
                ],
                if (metrics.isNotEmpty) ...[
                  KSpacing.vGapSm,
                  metricRow,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              if (metrics.isNotEmpty) ...[
                KSpacing.hGapMd,
                Flexible(child: metricRow),
              ],
              if (amountText != null) ...[
                KSpacing.hGapMd,
                Flexible(child: amountText),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final KDocumentHeaderMetric metric;

  const _HeaderMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metric.icon != null) ...[
            Icon(metric.icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                style: KTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                metric.value,
                style: KTypography.labelMedium.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
