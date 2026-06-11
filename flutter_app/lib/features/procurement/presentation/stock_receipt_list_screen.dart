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
import '../data/stock_receipt_repository.dart';

const _receiptTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Received', value: 'RECEIVED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class StockReceiptListScreen extends ConsumerStatefulWidget {
  const StockReceiptListScreen({super.key});

  @override
  ConsumerState<StockReceiptListScreen> createState() =>
      _StockReceiptListScreenState();
}

class _StockReceiptListScreenState
    extends ConsumerState<StockReceiptListScreen> {
  String? _status;
  String _search = '';
  List<Map<String, dynamic>> _currentReceipts = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentReceipts.length) return;
    final id = _currentReceipts[index]['id']?.toString();
    if (id != null) context.go('/stock-receipts/$id');
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(stockReceiptListProvider(null));

    return KKeyboardListWrapper(
      itemCount: () => _currentReceipts.length,
      onNew: () => context.go(Routes.stockReceiptCreate),
      onRefresh: () => ref.invalidate(stockReceiptListProvider(null)),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Goods Receipts',
            searchHint: 'Search receipt, supplier, invoice...',
            tabs: _receiptTabs,
            selectedTab: _status,
            onTabChanged: (value) => setState(() => _status = value),
            onSearchChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          Expanded(
            child: receiptsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load receipts',
                onRetry: () => ref.invalidate(stockReceiptListProvider(null)),
              ),
              data: (data) {
                final content = data['data'];
                final receipts = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (receipts.isEmpty) {
                  return KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No goods receipts yet',
                    subtitle:
                        'Record stock arrivals from your suppliers to update inventory and capture input GST.',
                    actionLabel: 'New Receipt',
                    onAction: () => context.go(Routes.stockReceiptCreate),
                  );
                }

                final receiptMaps = receipts
                    .whereType<Map>()
                    .map((receipt) => receipt.cast<String, dynamic>())
                    .where((receipt) {
                  final status = receipt['status']?.toString();
                  if (_status != null && status != _status) return false;
                  if (_search.isEmpty) return true;
                  final haystack = [
                    receipt['receiptNumber'],
                    receipt['supplierName'],
                    receipt['supplierInvoiceNo'],
                    receipt['status'],
                  ].whereType<Object>().join(' ').toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                _currentReceipts = receiptMaps;

                if (receiptMaps.isEmpty) {
                  return KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No matching receipts',
                    subtitle: 'Try another status or search term.',
                    actionLabel: 'Clear Filters',
                    onAction: () => setState(() {
                      _status = null;
                      _search = '';
                    }),
                  );
                }

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: receiptMaps,
                  onRefresh: () async =>
                      ref.invalidate(stockReceiptListProvider(null)),
                  mobileItemBuilder: (context, receipt) =>
                      _ReceiptCard(receipt: receipt),
                  tableBuilder: (context) =>
                      _ReceiptTable(receipts: receiptMaps),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.stockReceiptCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Receipt'),
        tooltip: 'New Receipt (N)',
      ),
    ));
  }
}

class _ReceiptTable extends StatelessWidget {
  final List<Map<String, dynamic>> receipts;

  const _ReceiptTable({required this.receipts});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Receipt')),
        DataColumn(label: Text('Supplier')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Lines')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: receipts.map((receipt) {
        final id = receipt['id']?.toString() ?? '';
        final number = receipt['receiptNumber']?.toString() ?? '--';
        final supplierName =
            receipt['supplierName']?.toString() ?? 'Unknown supplier';
        final status = receipt['status']?.toString() ?? 'DRAFT';
        final total = (receipt['totalAmount'] as num?)?.toDouble() ?? 0;
        final dateRaw = receipt['receiptDate']?.toString();
        final lineCount = (receipt['lines'] as List?)?.length ??
            (receipt['lineCount'] as num?)?.toInt() ??
            0;

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.go('/stock-receipts/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: number, width: 155)),
            DataCell(KTableTextCell(value: supplierName, width: 210)),
            DataCell(KTableDateCell(value: dateRaw)),
            DataCell(Text('$lineCount')),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableAmountCell(value: total)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open goods receipt',
              onPressed:
                  id.isEmpty ? null : () => context.go('/stock-receipts/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final number = receipt['receiptNumber'] as String? ?? '--';
    final supplierName =
        receipt['supplierName'] as String? ?? 'Unknown supplier';
    final status = receipt['status'] as String? ?? 'DRAFT';
    final total = (receipt['totalAmount'] as num?)?.toDouble() ?? 0;
    final dateRaw = receipt['receiptDate'] as String?;
    final lineCount = (receipt['lines'] as List?)?.length;

    return KCard(
      onTap: () {
        final id = receipt['id']?.toString();
        if (id != null) context.go('/stock-receipts/$id');
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(number, style: KTypography.labelLarge),
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
                if (dateRaw != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    '${DateFormatter.display(DateTime.parse(dateRaw))}'
                    '${lineCount != null ? ' • $lineCount line${lineCount == 1 ? '' : 's'}' : ''}',
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
