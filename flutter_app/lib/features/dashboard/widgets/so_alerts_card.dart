import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/dashboard_repository.dart';

/// Sales Order alert card for retail/pharmacy dashboard.
/// Shows pending, backordered, and partially shipped orders at a glance.
class SoAlertsCard extends ConsumerWidget {
  const SoAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(soAlertsProvider);

    return alertsAsync.when(
      loading: () => const KCard(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 80, child: Center(child: KLoading())),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final confirmed = (data['confirmedCount'] as num?)?.toInt() ?? 0;
        final backorder = (data['backorderCount'] as num?)?.toInt() ?? 0;
        final partial = (data['partiallyShippedCount'] as num?)?.toInt() ?? 0;
        final overdue = (data['overdueCount'] as num?)?.toInt() ?? 0;
        final draftChallans =
            (data['draftChallanCount'] as num?)?.toInt() ?? 0;
        final dispatchedChallans =
            (data['dispatchedChallanCount'] as num?)?.toInt() ?? 0;
        final deliveredChallans =
            (data['deliveredChallanCount'] as num?)?.toInt() ?? 0;
        final orders = (data['recentOrders'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        final total = confirmed + backorder + partial + draftChallans + dispatchedChallans;
        if (total == 0) return const SizedBox.shrink();

        return KCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: KColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pending_actions_outlined,
                          size: 18, color: KColors.warning),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dispatch Alerts',
                              style: KTypography.labelLarge),
                          if (overdue > 0)
                            Text(
                              '$overdue order${overdue > 1 ? 's' : ''} waiting 2+ days',
                              style: KTypography.labelSmall
                                  .copyWith(color: KColors.error),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(Routes.salesOrders),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              // Status summary chips
              if (confirmed > 0 || backorder > 0 || partial > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (confirmed > 0)
                        _StatusChip(
                          label: '$confirmed SO Ready',
                          color: KColors.success,
                          bgColor: KColors.successLight,
                          icon: Icons.check_circle_outline,
                        ),
                      if (backorder > 0)
                        _StatusChip(
                          label: '$backorder Backorder',
                          color: KColors.error,
                          bgColor: KColors.errorLight,
                          icon: Icons.hourglass_empty_outlined,
                        ),
                      if (partial > 0)
                        _StatusChip(
                          label: '$partial Partial',
                          color: KColors.warning,
                          bgColor: KColors.warningLight,
                          icon: Icons.splitscreen_outlined,
                        ),
                    ],
                  ),
                ),
              if (draftChallans > 0 ||
                  dispatchedChallans > 0 ||
                  deliveredChallans > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (draftChallans > 0)
                        _StatusChip(
                          label: '$draftChallans DC Draft',
                          color: KColors.primary,
                          bgColor: KColors.primaryLight,
                          icon: Icons.local_shipping_outlined,
                        ),
                      if (dispatchedChallans > 0)
                        _StatusChip(
                          label: '$dispatchedChallans Dispatched',
                          color: KColors.warning,
                          bgColor: KColors.warningLight,
                          icon: Icons.route_outlined,
                        ),
                      if (deliveredChallans > 0)
                        _StatusChip(
                          label: '$deliveredChallans Delivered',
                          color: KColors.success,
                          bgColor: KColors.successLight,
                          icon: Icons.done_all_outlined,
                        ),
                      TextButton(
                        onPressed: () => context.push('/delivery-challans'),
                        child: const Text('Open Challans'),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // Recent order rows
              ...orders.take(5).map((order) => _OrderRow(order: order)),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: KTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  final Map<String, dynamic> order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soNumber = order['orderNumber']?.toString() ?? '—';
    final contact = order['contactName']?.toString() ?? 'Walk-in';
    final status = order['status']?.toString() ?? '';
    final amount = (order['totalAmount'] as num?)?.toDouble() ?? 0;
    final days = (order['daysPending'] as num?)?.toInt() ?? 0;

    final statusColor = switch (status) {
      'BACKORDER' => KColors.error,
      'CONFIRMED' => KColors.success,
      'PARTIALLY_SHIPPED' => KColors.warning,
      _ => KColors.textSecondary,
    };
    final statusLabel = switch (status) {
      'BACKORDER' => 'Backorder',
      'CONFIRMED' => 'Ready',
      'PARTIALLY_SHIPPED' => 'Partial',
      _ => status,
    };

    return InkWell(
      onTap: () => context.push('/sales-orders/${order['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact,
                      style: KTypography.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(soNumber,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(statusLabel,
                          style: KTypography.labelSmall
                              .copyWith(color: statusColor, fontSize: 10)),
                    ),
                    if (days >= 2) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${days}d',
                            style: KTypography.labelSmall.copyWith(
                                color: KColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                KMoney(
                  amount,
                  size: KMoneySize.small,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
