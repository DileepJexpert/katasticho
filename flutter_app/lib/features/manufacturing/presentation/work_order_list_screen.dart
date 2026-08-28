import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/manufacturing_repository.dart';

class WorkOrderListScreen extends ConsumerStatefulWidget {
  const WorkOrderListScreen({super.key});

  @override
  ConsumerState<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends ConsumerState<WorkOrderListScreen> {
  String? _statusFilter;
  List<dynamic> _currentOrders = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentOrders.length) return;
    final id = (_currentOrders[index] as Map?)?['id']?.toString();
    if (id != null) context.go('/manufacturing/work-orders/$id');
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(workOrdersProvider(_statusFilter));

    return KKeyboardListWrapper(
      itemCount: () => _currentOrders.length,
      onNew: () => context.go(Routes.manufacturingWorkOrderCreate),
      onRefresh: () => ref.invalidate(workOrdersProvider(_statusFilter)),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Work Orders',
            actions: [
              IconButton(
                tooltip: 'Auto-create WOs from low-stock composites',
                icon: const Icon(Icons.replay_outlined),
                onPressed: _replenishFromReorder,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: _statusFilter == null, onTap: () => _setFilter(null)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Draft', selected: _statusFilter == 'DRAFT', onTap: () => _setFilter('DRAFT')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'In Progress', selected: _statusFilter == 'IN_PROGRESS', onTap: () => _setFilter('IN_PROGRESS')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Completed', selected: _statusFilter == 'COMPLETED', onTap: () => _setFilter('COMPLETED')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Cancelled', selected: _statusFilter == 'CANCELLED', onTap: () => _setFilter('CANCELLED')),
                ],
              ),
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: KLoading(message: 'Loading work orders...')),
              error: (e, _) => KErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(workOrdersProvider(_statusFilter)),
              ),
              data: (orders) {
                _currentOrders = orders;
                if (orders.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'No work orders',
                    subtitle: 'Create a work order to start production.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(workOrdersProvider(_statusFilter)),
                  child: ListView.builder(
                    padding: KSpacing.pagePadding,
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) => _WorkOrderCard(
                      order: orders[i],
                      onTap: () {
                        final id = orders[i]['id']?.toString();
                        if (id != null) context.go('/manufacturing/work-orders/$id');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.go(Routes.manufacturingWorkOrderCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Work Order'),
        tooltip: 'New Work Order (N)',
      ),
    ));
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
  }

  /// Sweeps low-stock composite items and drafts a WO per item.
  /// Idempotent on the server — safe to tap repeatedly.
  Future<void> _replenishFromReorder() async {
    try {
      final created = await ref
          .read(manufacturingRepositoryProvider)
          .autoCreateWoFromReorder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created.isEmpty
            ? 'No low-stock composite items — nothing to draft'
            : 'Created ${created.length} draft work order(s) from reorder sweep'),
      ));
      ref.invalidate(workOrdersProvider(_statusFilter));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Replenish failed: $e')),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final woNumber = order['workOrderNumber']?.toString() ?? '';
    final status = order['status']?.toString() ?? '';
    final qtyToProduce = order['quantityToProduce']?.toString() ?? '0';
    final qtyProduced = order['quantityProduced']?.toString() ?? '0';
    final totalCost = (order['totalCost'] as num?)?.toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      woNumber,
                      style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              if (order['finishedGoodName'] != null) ...[
                KSpacing.vGapXxs,
                Text(
                  order['finishedGoodName'].toString(),
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                ),
              ],
              KSpacing.vGapSm,
              Row(
                children: [
                  Text('Qty: $qtyProduced / $qtyToProduce', style: KTypography.bodySmall),
                  if (totalCost != null) ...[
                    KSpacing.hGapMd,
                    Text('Cost: ', style: KTypography.bodySmall),
                    KMoney(totalCost, size: KMoneySize.small),
                  ],
                ],
              ),
              if (order['notes'] != null && (order['notes'] as String).isNotEmpty) ...[
                KSpacing.vGapXs,
                Text(
                  order['notes'].toString(),
                  style: KTypography.caption.copyWith(color: KColors.textHint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
