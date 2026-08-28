import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/partner_network_repository.dart';

class OutgoingOrdersScreen extends ConsumerStatefulWidget {
  const OutgoingOrdersScreen({super.key});

  @override
  ConsumerState<OutgoingOrdersScreen> createState() => _OutgoingOrdersScreenState();
}

class _OutgoingOrdersScreenState extends ConsumerState<OutgoingOrdersScreen> {
  String? _statusFilter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(outgoingOrdersProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => ordersAsync.valueOrNull?.length ?? 0,
      onRefresh: () => ref.invalidate(outgoingOrdersProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Outgoing B2B Purchase Orders'),
          actions: [
            IconButton(
              tooltip: 'Refresh Orders',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(outgoingOrdersProvider),
            ),
          ],
        ),
        body: ordersAsync.when(
          loading: () => const KLoading(message: 'Loading outgoing purchase orders...'),
          error: (e, _) => Center(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: KErrorView(
                message: ApiErrorParser.message(e),
                onRetry: () => ref.invalidate(outgoingOrdersProvider),
              ),
            ),
          ),
          data: (orders) {
            final filtered = orders.where((order) {
              final status = (order['status'] ?? '').toString().toUpperCase();
              if (_statusFilter != null && status != _statusFilter) return false;
              if (_searchQuery.isEmpty) return true;
              final orderNo = (order['orderNumber'] ?? '').toString().toLowerCase();
              final seller = (order['sellerOrgName'] ?? '').toString().toLowerCase();
              final q = _searchQuery.toLowerCase();
              return orderNo.contains(q) || seller.contains(q);
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(outgoingOrdersProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders Placed with Suppliers',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track electronic purchase orders transmitted to network suppliers and monitor fulfillment.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${orders.length})',
                          selected: _statusFilter == null,
                          onSelected: () => setState(() => _statusFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Placed (Sent)',
                          selected: _statusFilter == 'PLACED',
                          onSelected: () => setState(() => _statusFilter = 'PLACED'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Confirmed',
                          selected: _statusFilter == 'CONFIRMED',
                          onSelected: () => setState(() => _statusFilter = 'CONFIRMED'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Dispatched',
                          selected: _statusFilter == 'DISPATCHED',
                          onSelected: () => setState(() => _statusFilter = 'DISPATCHED'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Delivered',
                          selected: _statusFilter == 'DELIVERED',
                          onSelected: () => setState(() => _statusFilter = 'DELIVERED'),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search by order # or supplier name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  KSpacing.vGapMd,
                  if (filtered.isEmpty)
                    KEmptyState(
                      icon: Icons.outbox_outlined,
                      title: 'No outgoing orders',
                      subtitle: _statusFilter != null
                          ? 'No orders in $_statusFilter status.'
                          : 'Orders placed to supplier catalogs via B2B network will appear here.',
                    )
                  else
                    ...filtered.map((order) {
                      return _OrderCard(
                        order: order,
                        onTap: () => context.push('/partner-network/orders/${order['id']}'),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: KTypography.labelSmall.copyWith(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: cs.primaryContainer,
      showCheckmark: false,
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orderNumber = order['orderNumber']?.toString() ?? 'Network Order';
    final sellerName = order['sellerOrgName']?.toString() ?? 'Supplier Org';
    final status = order['status']?.toString() ?? 'PLACED';
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
              ),
              child: Icon(Icons.outbox_rounded, color: cs.primary, size: 20),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        orderNumber,
                        style: KTypography.mono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      KStatusChip(
                        status: status,
                        label: status.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_outlined, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Supplier: $sellerName',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'PO Value: ',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      KMoney(totalAmount, style: KTypography.titleSmall.copyWith(color: KColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
