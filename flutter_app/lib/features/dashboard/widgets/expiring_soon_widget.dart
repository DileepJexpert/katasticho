import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class ExpiringSoonWidget extends ConsumerWidget {
  const ExpiringSoonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expiringSoonProvider);

    return KCard(
      title: 'Expiring Soon',
      subtitle: 'Items expiring within 90 days',
      child: async.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (err, _) => KErrorBanner(message: 'Failed to load: $err'),
        data: (items) {
          if (items.isEmpty) {
            return const KEmptyState(
              icon: Icons.check_circle_outline,
              title: 'No items expiring soon',
              subtitle: 'All batch items are within safe expiry range.',
            );
          }

          return Column(
            children: [
              for (var i = 0; i < items.length && i < 5; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ExpiringTile(
                  itemName: items[i].itemName,
                  batchNumber: items[i].batchNumber,
                  daysLeft: items[i].daysLeft,
                  qty: items[i].quantityOnHand,
                ),
              ],
              if (items.length > 5) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${items.length - 5} more',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExpiringTile extends StatelessWidget {
  final String itemName;
  final String batchNumber;
  final int daysLeft;
  final double qty;

  const _ExpiringTile({
    required this.itemName,
    required this.batchNumber,
    required this.daysLeft,
    required this.qty,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUrgent = daysLeft <= 30;
    final chipColor = isUrgent ? KColors.error : KColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.timer_outlined,
              size: 16,
              color: chipColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName, style: KTypography.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  'Batch: $batchNumber  |  Qty: ${_fmt(qty)}',
                  style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              daysLeft <= 0 ? 'Expired' : '$daysLeft days',
              style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
