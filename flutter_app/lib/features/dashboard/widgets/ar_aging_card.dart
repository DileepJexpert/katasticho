import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';

/// Reusable aging bucket breakdown — renders Current / 1-30 / 31-60 /
/// 61-90 / 90+ rows with colour-coded bars. Rendered inline under the
/// KPI grid when the Receivables or Payables tile is tapped.
class AgingBreakdown extends StatelessWidget {
  final String title;
  final double totalOutstanding;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double days90plus;
  final String reportRoute;
  final Color accentColor;

  const AgingBreakdown({
    super.key,
    required this.title,
    required this.totalOutstanding,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.days90plus,
    required this.reportRoute,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overdue = days1to30 + days31to60 + days61to90 + days90plus;

    final buckets = [
      _Bucket('Current', current, KColors.success),
      _Bucket('1–30 days', days1to30, KColors.primary),
      _Bucket('31–60 days', days31to60, KColors.warning),
      _Bucket('61–90 days', days61to90, const Color(0xFFE65100)),
      _Bucket('90+ days', days90plus, KColors.error),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: KTypography.h3.copyWith(color: cs.onSurface)),
              const Spacer(),
              Text(CurrencyFormatter.formatIndian(totalOutstanding),
                  style: KTypography.amountMedium),
            ],
          ),
          if (overdue > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${CurrencyFormatter.formatCompact(overdue)} overdue',
                style:
                    KTypography.labelSmall.copyWith(color: KColors.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final b in buckets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _BucketRow(bucket: b, total: totalOutstanding),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(reportRoute),
              icon: Icon(Icons.arrow_forward, size: 16, color: accentColor),
              label: Text('View Full Report',
                  style: KTypography.labelMedium
                      .copyWith(color: accentColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bucket {
  final String label;
  final double amount;
  final Color color;
  const _Bucket(this.label, this.amount, this.color);
}

class _BucketRow extends StatelessWidget {
  final _Bucket bucket;
  final double total;

  const _BucketRow({required this.bucket, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction =
        total > 0 ? (bucket.amount / total).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(bucket.label,
              style: KTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(bucket.color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            CurrencyFormatter.formatCompact(bucket.amount),
            style: KTypography.amountSmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
