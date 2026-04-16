import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

/// Purchases split across branches — same visual pattern as
/// [RevenueByBranchWidget] but sourced from AP summary data.
///
/// Only renders when 2+ branches exist. The parent widget layout
/// conditionally includes this widget based on branch count.
class PurchasesByBranchWidget extends ConsumerWidget {
  const PurchasesByBranchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apAsync = ref.watch(apSummaryProvider);

    return KCard(
      title: 'Purchases by Branch',
      child: apAsync.when(
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
              title: 'No branch data',
              subtitle: 'Purchase data by branch will appear here.',
            );
          }

          final rows = [...data.byBranch]
            ..sort((a, b) => b.purchases.compareTo(a.purchases));
          final maxPurchases = rows
              .map((r) => r.purchases)
              .fold<double>(0, (m, r) => r > m ? r : m);
          final totalPurchases =
              rows.fold<double>(0, (sum, r) => sum + r.purchases);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child:
                      _BranchBar(row: row, maxPurchases: maxPurchases),
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
                    CurrencyFormatter.formatIndian(totalPurchases),
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
  final BranchPurchaseRow row;
  final double maxPurchases;

  const _BranchBar({required this.row, required this.maxPurchases});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction =
        maxPurchases > 0 ? (row.purchases / maxPurchases) : 0.0;
    // Use secondary/teal to visually distinguish from revenue (primary/blue)
    final barColor = KColors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.branchName.isNotEmpty
                    ? row.branchName
                    : row.branchCode,
                style: KTypography.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              CurrencyFormatter.formatIndian(row.purchases),
              style: KTypography.amountSmall,
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${row.sharePercent.toStringAsFixed(0)}%',
                style:
                    KTypography.labelSmall.copyWith(color: barColor),
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
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
