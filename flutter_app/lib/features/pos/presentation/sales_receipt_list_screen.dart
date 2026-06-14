import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/sales_receipt_providers.dart';

const _paymentTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Cash', value: 'CASH'),
  KListTab(label: 'UPI', value: 'UPI'),
  KListTab(label: 'Card', value: 'CARD'),
];

class SalesReceiptListScreen extends ConsumerWidget {
  const SalesReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(receiptFilterProvider);
    final receiptsAsync = ref.watch(receiptListProvider);

    return KKeyboardListWrapper(
      itemCount: () => 0,
      onRefresh: () => ref.invalidate(receiptListProvider),
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Sales Receipts',
            searchHint: 'Search receipts...',
            tabs: _paymentTabs,
            selectedTab: filter.paymentMode,
            onTabChanged: (v) => ref
                .read(receiptFilterProvider.notifier)
                .state = filter.copyWith(paymentMode: v, page: 0),
            onSearchChanged: (_) {},
          ),
          Expanded(
            child: receiptsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load receipts',
                onRetry: () => ref.invalidate(receiptListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return const KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts yet',
                    subtitle: 'Sales receipts from POS will appear here',
                  );
                }

                final receipts = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (receipts.isEmpty) {
                  return KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts found',
                    subtitle: filter.paymentMode != null
                        ? 'No ${filter.paymentMode!.toLowerCase()} receipts'
                        : 'Sales receipts from POS will appear here',
                  );
                }

                final receiptMaps = receipts
                    .whereType<Map>()
                    .map((receipt) => receipt.cast<String, dynamic>())
                    .toList();

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: receiptMaps,
                  onRefresh: () async => ref.invalidate(receiptListProvider),
                  mobileItemBuilder: (context, receipt) =>
                      _ReceiptCard(receipt: receipt),
                  tableBuilder: (context) => _ReceiptTable(
                    receipts: receiptMaps,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
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
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Payment')),
        DataColumn(label: Text('Items')),
        DataColumn(label: Text('Subtotal')),
        DataColumn(label: Text('Tax')),
        DataColumn(label: Text('Total')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: receipts.map((receipt) {
        final id = receipt['id']?.toString() ?? '';
        final receiptNumber = receipt['receiptNumber']?.toString() ?? '--';
        final date = receipt['receiptDate']?.toString() ?? '';
        final paymentMode = receipt['paymentMode']?.toString() ?? '--';
        final contactName =
            receipt['contactName']?.toString() ?? 'Walk-in Customer';
        final lineCount = (receipt['lines'] as List?)?.length ??
            (receipt['lineCount'] as num?)?.toInt() ??
            0;
        final subtotal = (receipt['subtotal'] as num?)?.toDouble() ?? 0;
        final tax = (receipt['taxAmount'] as num?)?.toDouble() ?? 0;
        final total = (receipt['total'] as num?)?.toDouble() ??
            (receipt['totalAmount'] as num?)?.toDouble() ??
            0;

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.push('/sales-receipts/$id');
          },
          cells: [
            DataCell(_ReceiptNumberCell(
              receiptNumber: receiptNumber,
              paymentMode: paymentMode,
            )),
            DataCell(KTableTextCell(value: contactName, width: 170)),
            DataCell(_ReceiptDateCell(value: date)),
            DataCell(_PaymentModeCell(mode: paymentMode)),
            DataCell(Text('$lineCount')),
            DataCell(KTableAmountCell(value: subtotal)),
            DataCell(KTableAmountCell(value: tax)),
            DataCell(KTableAmountCell(value: total)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open receipt',
              onPressed:
                  id.isEmpty ? null : () => context.push('/sales-receipts/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _ReceiptNumberCell extends StatelessWidget {
  final String receiptNumber;
  final String paymentMode;

  const _ReceiptNumberCell({
    required this.receiptNumber,
    required this.paymentMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _paymentIconFor(paymentMode),
              color: cs.primary,
              size: 17,
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              receiptNumber,
              style: KTypography.labelLarge.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDateCell extends StatelessWidget {
  final String value;

  const _ReceiptDateCell({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const Text('--');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return Text(value);
    return Text(DateFormatter.short(parsed));
  }
}

class _PaymentModeCell extends StatelessWidget {
  final String mode;

  const _PaymentModeCell({required this.mode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_paymentIconFor(mode), size: 14, color: cs.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            mode,
            style: KTypography.labelSmall.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = receipt['id']?.toString() ?? '';
    final receiptNumber = receipt['receiptNumber']?.toString() ?? '';
    final date = receipt['receiptDate']?.toString() ?? '';
    final total = (receipt['total'] as num?)?.toDouble() ?? 0;
    final paymentMode = receipt['paymentMode']?.toString() ?? '';
    final contactName = receipt['contactName']?.toString();
    final lineCount = (receipt['lines'] as List?)?.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sales-receipts/$id'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_paymentIconFor(paymentMode),
                    color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(receiptNumber, style: KTypography.labelMedium),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            paymentMode,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contactName ?? 'Walk-in Customer',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lineCount != null)
                      Text(
                        '$lineCount item${lineCount == 1 ? '' : 's'} • $date',
                        style: KTypography.labelSmall.copyWith(
                            color: KColors.textSecondary, fontSize: 10),
                      ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _paymentIconFor(String? mode) => switch (mode?.toUpperCase()) {
      'CASH' => Icons.payments_outlined,
      'UPI' => Icons.qr_code,
      'CARD' => Icons.credit_card,
      _ => Icons.payment,
    };
