import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

/// Revenue split across branches for the active dashboard date range.
/// Driven by [todaySalesProvider.byBranch] — no extra round-trip.
///
/// Renders a single-row bar per branch (horizontal stacked segment +
/// branch name + absolute ₹ value + share %) sorted by revenue desc.
/// When the API returns zero rows, falls back to a K-styled empty state
/// and hints the demo-seed endpoint for onboarding screenshots.
class RevenueByBranchWidget extends ConsumerWidget {
  const RevenueByBranchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todaySalesProvider);

    return KCard(
      title: 'Revenue by Branch',
      child: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Failed to load: $err',
            style: KTypography.bodySmall.copyWith(color: KColors.error),
          ),
        ),
        data: (data) {
          if (data.byBranch.isEmpty) {
            return const KEmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'No branches yet',
              subtitle: 'Create branches from Settings → Branches to split revenue across locations.',
            );
          }

          // Descending by revenue — server already does this but we defend
          // against any client-side reorder.
          final rows = [...data.byBranch]
            ..sort((a, b) => b.revenue.compareTo(a.revenue));
          final maxRevenue = rows.map((r) => r.revenue).fold<double>(
              0, (m, r) => r > m ? r : m);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _BranchBar(row: row, maxRevenue: maxRevenue),
                ),
              KSpacing.vGapSm,
              Row(
                children: [
                  Text(
                    'Total',
                    style: KTypography.labelMedium.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.formatIndian(data.revenue),
                    style: KTypography.amountMedium,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BranchBar extends StatelessWidget {
  final BranchSalesRow row;
  final double maxRevenue;

  const _BranchBar({required this.row, required this.maxRevenue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxRevenue > 0 ? (row.revenue / maxRevenue) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.branchName.isNotEmpty ? row.branchName : row.branchCode,
                style: KTypography.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              CurrencyFormatter.formatIndian(row.revenue),
              style: KTypography.amountSmall,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${row.sharePercent.toStringAsFixed(0)}%',
                style: KTypography.labelSmall.copyWith(color: cs.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        KShimmerCard(height: 22),
        SizedBox(height: 10),
        KShimmerCard(height: 22),
        SizedBox(height: 10),
        KShimmerCard(height: 22),
      ],
    );
  }
}
