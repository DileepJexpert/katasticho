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

/// Recent Purchase Activity — shows the latest 5 posted bills.
/// Each row is tappable and navigates to bill detail.
class RecentBillsWidget extends ConsumerWidget {
  const RecentBillsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(recentBillsProvider);

    return KCard(
      title: 'Recent Purchase Activity',
      action: TextButton(
        onPressed: () => context.go('/bills'),
        child: const Text('View All'),
      ),
      child: billsAsync.when(
        loading: () => const _Skeleton(),
        error: (err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Failed to load',
            style: KTypography.bodySmall.copyWith(color: KColors.error),
          ),
        ),
        data: (bills) {
          if (bills.isEmpty) {
            return const KEmptyState(
              icon: Icons.receipt_outlined,
              title: 'No recent bills',
              subtitle: 'Posted bills will appear here',
            );
          }

          return Column(
            children: bills.map((bill) => _BillRow(bill: bill)).toList(),
          );
        },
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final RecentBillData bill;

  const _BillRow({required this.bill});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (bill.id.isNotEmpty) {
          context.go('/bills/${bill.id}');
        }
      },
      borderRadius: KSpacing.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: KColors.primary,
                size: 18,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.billNumber, style: KTypography.labelMedium),
                  Text(
                    bill.vendorName,
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatIndian(bill.totalAmount),
                  style: KTypography.amountSmall,
                ),
                if (bill.billDate.isNotEmpty)
                  Text(
                    bill.billDate,
                    style: KTypography.labelSmall.copyWith(
                      color: KColors.textHint,
                    ),
                  ),
              ],
            ),
            KSpacing.hGapSm,
            const Icon(Icons.chevron_right,
                size: 16, color: KColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        KShimmerCard(height: 48),
        SizedBox(height: 8),
        KShimmerCard(height: 48),
        SizedBox(height: 8),
        KShimmerCard(height: 48),
      ],
    );
  }
}
