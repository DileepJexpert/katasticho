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
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../data/purchase_order_repository.dart';

const _poTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Sent', value: 'SENT'),
  KListTab(label: 'Partial', value: 'PARTIAL'),
  KListTab(label: 'Received', value: 'RECEIVED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState
    extends ConsumerState<PurchaseOrderListScreen> {
  String? _status;
  String _search = '';
  List<Map<String, dynamic>> _currentPurchaseOrders = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentPurchaseOrders.length) return;
    final id = _currentPurchaseOrders[index]['id']?.toString();
    if (id != null) context.go('/purchase-orders/$id');
  }

  @override
  Widget build(BuildContext context) {
    final posAsync = ref.watch(purchaseOrdersProvider);

    return KKeyboardListWrapper(
      itemCount: () => _currentPurchaseOrders.length,
      onNew: () => context.go(Routes.purchaseOrderCreate),
      onRefresh: () => ref.invalidate(purchaseOrdersProvider),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Purchase Orders',
            searchHint: 'Search PO number, supplier...',
            tabs: _poTabs,
            selectedTab: _status,
            onTabChanged: (value) => setState(() => _status = value),
            onSearchChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          Expanded(
            child: posAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load purchase orders',
                onRetry: () => ref.invalidate(purchaseOrdersProvider),
              ),
              data: (pos) {
                if (pos.isEmpty) {
                  return KEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'No purchase orders yet',
                    subtitle:
                        'Create purchase orders to track what you\'ve ordered from suppliers.',
                    actionLabel: 'New PO',
                    onAction: () => context.go(Routes.purchaseOrderCreate),
                  );
                }

                final poMaps = pos
                    .whereType<Map>()
                    .map((po) => po.cast<String, dynamic>())
                    .where((po) {
                  final status = po['status']?.toString();
                  if (_status != null && status != _status) return false;
                  if (_search.isEmpty) return true;
                  final haystack = [
                    po['poNumber'],
                    po['supplierName'],
                    po['status'],
                  ].whereType<Object>().join(' ').toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                _currentPurchaseOrders = poMaps;

                if (poMaps.isEmpty) {
                  return KEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'No matching purchase orders',
                    subtitle: 'Try another status or search term.',
                    actionLabel: 'Clear Filters',
                    onAction: () => setState(() {
                      _status = null;
                      _search = '';
                    }),
                  );
                }

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: poMaps,
                  onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
                  mobileItemBuilder: (context, po) => _PoCard(po: po),
                  tableBuilder: (context) => _PoTable(pos: poMaps),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.purchaseOrderCreate),
        icon: const Icon(Icons.add),
        label: const Text('New PO'),
      ),
    ));
  }
}

class _PoTable extends StatelessWidget {
  final List<Map<String, dynamic>> pos;
  const _PoTable({required this.pos});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('PO Number')),
        DataColumn(label: Text('Supplier')),
        DataColumn(label: Text('Order Date')),
        DataColumn(label: Text('Expected Delivery')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: pos.map((po) {
        final id = po['id']?.toString() ?? '';
        final poNumber = po['poNumber']?.toString() ?? '--';
        final supplierName = po['supplierName']?.toString() ?? 'Unknown supplier';
        final status = po['status']?.toString() ?? 'DRAFT';
        final total = (po['totalAmount'] as num?)?.toDouble() ?? 0;
        final orderDate = po['orderDate']?.toString();
        final deliveryDate = po['expectedDeliveryDate']?.toString();

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.go('/purchase-orders/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: poNumber, width: 130)),
            DataCell(KTableTextCell(value: supplierName, width: 200)),
            DataCell(KTableDateCell(value: orderDate)),
            DataCell(KTableDateCell(value: deliveryDate)),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableAmountCell(value: total)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open purchase order',
              onPressed:
                  id.isEmpty ? null : () => context.go('/purchase-orders/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _PoCard extends StatelessWidget {
  final Map<String, dynamic> po;
  const _PoCard({required this.po});

  @override
  Widget build(BuildContext context) {
    final poNumber = po['poNumber'] as String? ?? '--';
    final supplierName = po['supplierName'] as String? ?? 'Unknown supplier';
    final status = po['status'] as String? ?? 'DRAFT';
    final total = (po['totalAmount'] as num?)?.toDouble() ?? 0;
    final orderDateRaw = po['orderDate'] as String?;
    final lineCount = (po['lines'] as List?)?.length;

    return KCard(
      onTap: () {
        final id = po['id']?.toString();
        if (id != null) context.go('/purchase-orders/$id');
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(poNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  supplierName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (orderDateRaw != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    '${DateFormatter.display(DateTime.parse(orderDateRaw))}'
                    '${lineCount != null ? ' • $lineCount item${lineCount == 1 ? '' : 's'}' : ''}',
                    style: KTypography.bodySmall,
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
              Text('Total', style: KTypography.labelSmall),
            ],
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
