import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/sales_order_providers.dart';
import '../data/sales_order_repository.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Confirmed', value: 'CONFIRMED'),
  KListTab(label: 'Partial Ship', value: 'PARTIALLY_SHIPPED'),
  KListTab(label: 'Shipped', value: 'SHIPPED'),
  KListTab(label: 'Invoiced', value: 'INVOICED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class SalesOrderListScreen extends ConsumerStatefulWidget {
  const SalesOrderListScreen({super.key});

  @override
  ConsumerState<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends ConsumerState<SalesOrderListScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count order${count == 1 ? '' : 's'}?'),
        content: const Text(
            'Only DRAFT orders can be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(salesOrderRepositoryProvider);
    final ids = _selectedIds.toList();
    int success = 0;
    int fail = 0;
    for (final id in ids) {
      try {
        await repo.deleteSalesOrder(id);
        success++;
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    ref.invalidate(salesOrderListProvider);
    final msg = fail == 0
        ? 'Deleted $success successfully'
        : 'Deleted $success, $fail failed';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(salesOrderFilterProvider);
    final ordersAsync = ref.watch(salesOrderListProvider);
    final inSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Sales Orders',
            searchHint: 'Search sales orders\u2026',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(salesOrderFilterProvider.notifier)
                .state = filter.copyWith(status: v, page: 0),
            onSearchChanged: (q) => ref
                .read(salesOrderFilterProvider.notifier)
                .state = filter.copyWith(search: q.isEmpty ? null : q, page: 0),
            actions: [
              KSavedViewButton(
                entityType: 'sales_orders',
                currentFilters: {
                  'status': filter.status,
                  'search': filter.search,
                },
                onViewSelected: (filters) {
                  ref.read(salesOrderFilterProvider.notifier).state =
                      filter.copyWith(
                    status: filters['status'],
                    search: filters['search'],
                    page: 0,
                  );
                },
              ),
            ],
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load sales orders',
                onRetry: () => ref.invalidate(salesOrderListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No sales orders yet',
                    subtitle: 'Create your first sales order to get started',
                    actionLabel: 'Create Sales Order',
                    onAction: () => context.go(Routes.salesOrderCreate),
                  );
                }

                final orders = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (orders.isEmpty) {
                  return KEmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No sales orders found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status!.toLowerCase()} sales orders'
                        : 'Create your first sales order',
                    actionLabel: 'Create Sales Order',
                    onAction: () => context.go(Routes.salesOrderCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesOrderListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final order = orders[index] as Map<String, dynamic>;
                      final id = order['id']?.toString() ?? '';
                      return _SalesOrderCard(
                        order: order,
                        selected: _selectedIds.contains(id),
                        inSelection: inSelection,
                        onToggleSelect: () => _toggleSelect(id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Routes.salesOrderCreate),
              icon: const Icon(Icons.add),
              label: const Text('New Order'),
            ),
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _SalesOrderCard({
    required this.order,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? 'DRAFT';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final customerName = order['contactName'] as String? ?? 'Unknown';
    final orderNumber = order['salesOrderNumber'] as String? ?? '--';
    final orderDate = order['orderDate'] as String?;
    final expectedShipmentDate = order['expectedShipmentDate'] as String?;

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        final id = order['id']?.toString();
        if (id != null) context.go('/sales-orders/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          if (inSelection) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
            KSpacing.hGapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(orderNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  customerName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (orderDate != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Ordered: ${DateFormatter.display(DateTime.parse(orderDate))}',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
                if (expectedShipmentDate != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Ship by: ${DateFormatter.display(DateTime.parse(expectedShipmentDate))}',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountMedium,
              ),
            ],
          ),
          KSpacing.hGapSm,
          if (!inSelection)
            const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
