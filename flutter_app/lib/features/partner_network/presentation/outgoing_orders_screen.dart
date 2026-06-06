import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/widgets.dart';
import '../data/partner_network_repository.dart';

class OutgoingOrdersScreen extends ConsumerWidget {
  const OutgoingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(outgoingOrdersProvider);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Outgoing B2B Orders',
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KErrorView(message: e.toString(), onRetry: () => ref.invalidate(outgoingOrdersProvider)),
              data: (orders) {
                if (orders.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.outbox_outlined,
                    title: 'No outgoing orders',
                    subtitle: 'Place a B2B order from the supplier search.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(outgoingOrdersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) => _OrderCard(
                      order: orders[i],
                      onTap: () => context.push('/partner-network/orders/${orders[i]['id']}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderNumber = order['orderNumber']?.toString() ?? '';
    final sellerName = order['sellerOrgName']?.toString() ?? 'Unknown';
    final status = order['status']?.toString() ?? '';
    final totalAmount = order['totalAmount'];

    return KCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orderNumber, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('To: $sellerName', style: theme.textTheme.bodySmall),
                  if (totalAmount != null) ...[
                    const SizedBox(height: 2),
                    Text('₹$totalAmount', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            KStatusChip(status: status),
          ],
        ),
      ),
    );
  }
}
