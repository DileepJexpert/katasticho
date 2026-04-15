import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

/// "Top Selling Today" — ranked list of items by invoiced quantity over
/// the active dashboard date range. Free-text invoice lines are filtered
/// out server-side so every row maps to a real item the user can click
/// through to.
///
/// Free-text lines (item_id NULL) are excluded server-side, so every
/// tile is tappable and routes to /items/:id.
class TopSellingWidget extends ConsumerWidget {
  const TopSellingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topSellingProvider);

    return KCard(
      title: 'Top Selling Today',
      child: async.when(
        loading: () => const _Skeleton(),
        error: (err, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Failed to load: $err',
            style: KTypography.bodySmall.copyWith(color: KColors.error),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const KEmptyState(
              icon: Icons.insights_outlined,
              title: 'No sales yet',
              subtitle: 'Create an invoice to see your best-selling items here.',
            );
          }

          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TopSellingTile(
                  rank: items[i].rank == 0 ? i + 1 : items[i].rank,
                  itemId: items[i].itemId,
                  name: items[i].name,
                  unit: items[i].unit,
                  quantity: items[i].quantity,
                  revenue: items[i].revenue,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TopSellingTile extends StatelessWidget {
  final int rank;
  final String itemId;
  final String name;
  final String? unit;
  final double quantity;
  final double revenue;

  const _TopSellingTile({
    required this.rank,
    required this.itemId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        child: Text(
          '$rank',
          style: KTypography.labelMedium.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(name, style: KTypography.labelMedium, maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_fmtQty(quantity)} ${unit ?? ''} sold',
        style: KTypography.bodySmall,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            CurrencyFormatter.formatIndian(revenue),
            style: KTypography.amountSmall,
          ),
          Text('revenue', style: KTypography.labelSmall),
        ],
      ),
      onTap: itemId.isEmpty ? null : () => context.go('/items/$itemId'),
    );
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        KShimmerCard(height: 44),
        SizedBox(height: 8),
        KShimmerCard(height: 44),
        SizedBox(height: 8),
        KShimmerCard(height: 44),
      ],
    );
  }
}
