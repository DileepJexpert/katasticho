import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

/// Expandable AR receivables card with aging bucket breakdown.
/// Mirrors Zoho Books-style drill-down: tap anywhere on the card to
/// reveal a Current / 1-30 / 31-60 / 61-90 / 90+ breakdown with
/// colour-coded progress bars and a shortcut to the full ageing report.
class ArAgingCard extends ConsumerStatefulWidget {
  const ArAgingCard({super.key});

  @override
  ConsumerState<ArAgingCard> createState() => _ArAgingCardState();
}

class _ArAgingCardState extends ConsumerState<ArAgingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(arAgingProvider);
    final cs = Theme.of(context).colorScheme;

    return KCard(
      padding: EdgeInsets.zero,
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: KShimmerCard(height: 56),
        ),
        error: (_, __) => _ErrorHeader(
            icon: Icons.account_balance_wallet,
            color: KColors.warning,
            label: 'Receivables'),
        data: (data) => Column(
          children: [
            _Header(
              icon: Icons.account_balance_wallet_outlined,
              color: KColors.warning,
              label: 'Receivables',
              amount: data.totalOutstanding,
              overdueAmount: data.days1to30 +
                  data.days31to60 +
                  data.days61to90 +
                  data.days90plus,
              expanded: _expanded,
              onTap: _toggle,
            ),
            SizeTransition(
              sizeFactor: _expand,
              child: _AgingBreakdown(
                current: data.current,
                days1to30: data.days1to30,
                days31to60: data.days31to60,
                days61to90: data.days61to90,
                days90plus: data.days90plus,
                total: data.totalOutstanding,
                onViewReport: () => context.go('/reports/ageing'),
                cs: cs,
                accentColor: KColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable AP payables card — same structure as AR, opposite direction.
class ApAgingCard extends ConsumerStatefulWidget {
  const ApAgingCard({super.key});

  @override
  ConsumerState<ApAgingCard> createState() => _ApAgingCardState();
}

class _ApAgingCardState extends ConsumerState<ApAgingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(apAgingProvider);
    final cs = Theme.of(context).colorScheme;

    return KCard(
      padding: EdgeInsets.zero,
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: KShimmerCard(height: 56),
        ),
        error: (_, __) => _ErrorHeader(
            icon: Icons.payments_outlined,
            color: KColors.error,
            label: 'Payables'),
        data: (data) => Column(
          children: [
            _Header(
              icon: Icons.payments_outlined,
              color: KColors.error,
              label: 'Payables',
              amount: data.totalOutstanding,
              overdueAmount: data.days1to30 +
                  data.days31to60 +
                  data.days61to90 +
                  data.days90plus,
              expanded: _expanded,
              onTap: _toggle,
            ),
            SizeTransition(
              sizeFactor: _expand,
              child: _AgingBreakdown(
                current: data.current,
                days1to30: data.days1to30,
                days31to60: data.days31to60,
                days61to90: data.days61to90,
                days90plus: data.days90plus,
                total: data.totalOutstanding,
                onViewReport: () => context.go('/reports/ap-ageing'),
                cs: cs,
                accentColor: KColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double amount;
  final double overdueAmount;
  final bool expanded;
  final VoidCallback onTap;

  const _Header({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
    required this.overdueAmount,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: KTypography.labelMedium
                          .copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatIndian(amount),
                    style: KTypography.amountMedium,
                  ),
                ],
              ),
            ),
            if (overdueAmount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: KColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${CurrencyFormatter.formatCompact(overdueAmount)} overdue',
                  style: KTypography.labelSmall
                      .copyWith(color: KColors.error),
                ),
              ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 260),
              child: Icon(Icons.keyboard_arrow_down,
                  color: cs.onSurfaceVariant, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingBreakdown extends StatelessWidget {
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double days90plus;
  final double total;
  final VoidCallback onViewReport;
  final ColorScheme cs;
  final Color accentColor;

  const _AgingBreakdown({
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.days90plus,
    required this.total,
    required this.onViewReport,
    required this.cs,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = [
      _Bucket('Current', current, KColors.success),
      _Bucket('1–30 days', days1to30, KColors.primary),
      _Bucket('31–60 days', days31to60, KColors.warning),
      _Bucket('61–90 days', days61to90, const Color(0xFFE65100)),
      _Bucket('90+ days', days90plus, KColors.error),
    ];

    return Column(
      children: [
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              for (final b in buckets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _BucketRow(bucket: b, total: total),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
        TextButton(
          onPressed: onViewReport,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View Full Report',
                  style: KTypography.labelMedium
                      .copyWith(color: accentColor)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 14, color: accentColor),
            ],
          ),
        ),
      ],
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
    final fraction = total > 0 ? (bucket.amount / total).clamp(0.0, 1.0) : 0.0;

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

class _ErrorHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _ErrorHeader(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: color),
          KSpacing.hGapSm,
          Text(label, style: KTypography.labelMedium),
          const Spacer(),
          Text('—', style: KTypography.amountMedium),
        ],
      ),
    );
  }
}
