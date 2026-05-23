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
import '../data/stock_receipt_repository.dart';

class StockReceiptDetailScreen extends ConsumerWidget {
  final String receiptId;

  const StockReceiptDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(stockReceiptDetailProvider(receiptId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.stockReceipts),
        ),
        actions: [
          receiptAsync.maybeWhen(
            data: (data) {
              final receipt = (data['data'] ?? data) as Map<String, dynamic>;
              final status = receipt['status'] as String? ?? '';
              if (status == 'CANCELLED') return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (v) => _handleAction(context, ref, receipt, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel Receipt',
                        style: TextStyle(color: KColors.error)),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const KLoading(message: 'Loading receipt...'),
        error: (err, st) {
          debugPrint('[GrnDetail] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load receipt',
            onRetry: () =>
                ref.invalidate(stockReceiptDetailProvider(receiptId)),
          );
        },
        data: (data) {
          final receipt = (data['data'] ?? data) as Map<String, dynamic>;
          return _ReceiptBody(receipt: receipt);
        },
      ),
      bottomNavigationBar: receiptAsync.whenOrNull(
        data: (data) {
          final receipt = (data['data'] ?? data) as Map<String, dynamic>;
          final status = receipt['status'] as String? ?? '';
          if (status != 'DRAFT') return null;
          return Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total', style: KTypography.bodySmall),
                      Text(
                        CurrencyFormatter.formatIndian(
                            (receipt['totalAmount'] as num?)?.toDouble() ?? 0),
                        style: KTypography.amountLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Receive Stock',
                    icon: Icons.check_circle_outline,
                    onPressed: () => _confirmReceive(context, ref, receipt),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref,
      Map<String, dynamic> receipt, String action) async {
    if (action == 'cancel') {
      await _confirmCancel(context, ref, receipt);
    }
  }

  Future<void> _confirmReceive(
      BuildContext context, WidgetRef ref, Map<String, dynamic> receipt) async {
    final lineCount = (receipt['lines'] as List?)?.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Stock?'),
        content: Text(
          'This will post $lineCount stock movement${lineCount == 1 ? '' : 's'} '
          'and update inventory balances. The receipt will move to RECEIVED '
          'and cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Receive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(stockReceiptRepositoryProvider);
      await repo.receiveReceipt(receipt['id']?.toString() ?? '');
      ref.invalidate(stockReceiptDetailProvider(receiptId));
      ref.invalidate(stockReceiptListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock received successfully')),
        );
      }
    } catch (e) {
      debugPrint('[GrnDetail] receive failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to receive stock'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, Map<String, dynamic> receipt) async {
    final reasonCtl = TextEditingController();
    final status = receipt['status'] as String? ?? '';
    final isReceived = status == 'RECEIVED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Receipt?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReceived
                  ? 'This receipt was already received. Cancelling will reverse all stock movements.'
                  : 'This will mark the draft as cancelled.',
              style: KTypography.bodyMedium,
            ),
            KSpacing.vGapMd,
            KTextField(
              label: 'Reason',
              controller: reasonCtl,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Receipt'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (reasonCtl.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A cancel reason is required')),
        );
      }
      return;
    }
    try {
      final repo = ref.read(stockReceiptRepositoryProvider);
      await repo.cancelReceipt(
          receipt['id']?.toString() ?? '', reasonCtl.text.trim());
      ref.invalidate(stockReceiptDetailProvider(receiptId));
      ref.invalidate(stockReceiptListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt cancelled')),
        );
      }
    } catch (e) {
      debugPrint('[GrnDetail] cancel failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to cancel receipt'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }
}

class _ReceiptBody extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const _ReceiptBody({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final number = receipt['receiptNumber'] as String? ?? '--';
    final status = receipt['status'] as String? ?? 'DRAFT';
    final supplierName =
        receipt['supplierName'] as String? ?? 'Unknown supplier';
    final dateRaw = receipt['receiptDate'] as String?;
    final supInvNo = receipt['supplierInvoiceNo'] as String?;
    final supInvDate = receipt['supplierInvoiceDate'] as String?;
    final notes = receipt['notes'] as String?;
    final cancelReason = receipt['cancelReason'] as String?;
    final subtotal = (receipt['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (receipt['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (receipt['totalAmount'] as num?)?.toDouble() ?? 0;
    final lines =
        (receipt['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReceiptInfoPanel(
              receiptDate: dateRaw,
              supplierInvoiceNo: supInvNo,
              supplierInvoiceDate: supInvDate,
              notes: notes,
              cancelReason: cancelReason,
            ),
            KSpacing.vGapMd,
            _ReceiptItemsPanel(lines: lines),
          ],
        );

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: KSpacing.md,
                    runSpacing: KSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(KSpacing.radiusMd),
                        ),
                        child: Icon(Icons.inventory_2_outlined,
                            color: cs.onPrimaryContainer),
                      ),
                      SizedBox(
                        width: isWide ? 560 : constraints.maxWidth - 48,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(number,
                                style: KTypography.h2,
                                overflow: TextOverflow.ellipsis),
                            KSpacing.vGapXxs,
                            Text(supplierName,
                                style: KTypography.bodyLarge,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      KStatusChip(status: status),
                    ],
                  ),
                  KSpacing.vGapLg,
                  Wrap(
                    spacing: KSpacing.md,
                    runSpacing: KSpacing.md,
                    children: [
                      _ReceiptMetric(
                        label: 'Receipt total',
                        value: CurrencyFormatter.formatIndian(total),
                        icon: Icons.payments_outlined,
                      ),
                      _ReceiptMetric(
                        label: 'Lines',
                        value: lines.length.toString(),
                        icon: Icons.format_list_numbered,
                      ),
                      _ReceiptMetric(
                        label: 'Input GST',
                        value: CurrencyFormatter.formatIndian(tax),
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftColumn),
                  KSpacing.hGapMd,
                  SizedBox(
                    width: 340,
                    child: _ReceiptSummaryPanel(
                      subtotal: subtotal,
                      tax: tax,
                      total: total,
                    ),
                  ),
                ],
              )
            else ...[
              leftColumn,
              KSpacing.vGapMd,
              _ReceiptSummaryPanel(
                subtotal: subtotal,
                tax: tax,
                total: total,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReceiptMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReceiptMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: KTypography.labelSmall,
                    overflow: TextOverflow.ellipsis),
                KSpacing.vGapXxs,
                Text(value,
                    style: KTypography.amountSmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptInfoPanel extends StatelessWidget {
  final String? receiptDate;
  final String? supplierInvoiceNo;
  final String? supplierInvoiceDate;
  final String? notes;
  final String? cancelReason;

  const _ReceiptInfoPanel({
    required this.receiptDate,
    required this.supplierInvoiceNo,
    required this.supplierInvoiceDate,
    required this.notes,
    required this.cancelReason,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Receipt Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (receiptDate != null)
            KDetailRow(
              label: 'Receipt Date',
              value: DateFormatter.display(DateTime.parse(receiptDate!)),
            ),
          if (supplierInvoiceNo != null && supplierInvoiceNo!.isNotEmpty)
            KDetailRow(label: 'Supplier Invoice', value: supplierInvoiceNo!),
          if (supplierInvoiceDate != null && supplierInvoiceDate!.isNotEmpty)
            KDetailRow(
              label: 'Supplier Inv. Date',
              value:
                  DateFormatter.display(DateTime.parse(supplierInvoiceDate!)),
            ),
          if (notes != null && notes!.isNotEmpty) ...[
            KSpacing.vGapMd,
            _TextBlock(title: 'Notes', value: notes!),
          ],
          if (cancelReason != null && cancelReason!.isNotEmpty) ...[
            KSpacing.vGapMd,
            _TextBlock(title: 'Cancellation', value: cancelReason!),
          ],
        ],
      ),
    );
  }
}

class _ReceiptItemsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> lines;

  const _ReceiptItemsPanel({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const KCard(
        title: 'Received Items',
        child: KEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No items on this receipt',
          subtitle: 'Received items will appear here once added.',
        ),
      );
    }

    return KCard(
      title: 'Received Items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: KSpacing.lg,
          headingRowHeight: 44,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Qty'), numeric: true),
            DataColumn(label: Text('Rate'), numeric: true),
            DataColumn(label: Text('GST'), numeric: true),
            DataColumn(label: Text('Amount'), numeric: true),
          ],
          rows: lines.map((line) {
            final desc = line['description'] as String? ?? 'Item';
            final sku = line['itemSku'] as String? ?? '';
            final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
            final uom = line['unitOfMeasure'] as String? ?? '';
            final unitPrice = (line['unitPrice'] as num?)?.toDouble() ?? 0;
            final taxAmount = (line['taxAmount'] as num?)?.toDouble() ?? 0;
            final lineTotal = (line['lineTotal'] as num?)?.toDouble() ?? 0;
            final batch = line['batchNumber'] as String? ?? '';
            final qtyText =
                qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2);
            final meta = [
              if (sku.isNotEmpty) 'SKU: $sku',
              if (batch.isNotEmpty) 'Batch: $batch',
            ].join(' / ');

            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc,
                            style: KTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                        if (meta.isNotEmpty) ...[
                          KSpacing.vGapXxs,
                          Text(meta,
                              style: KTypography.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ),
                DataCell(Text('$qtyText $uom')),
                DataCell(Text(CurrencyFormatter.formatIndian(unitPrice))),
                DataCell(Text(CurrencyFormatter.formatIndian(taxAmount))),
                DataCell(Text(
                  CurrencyFormatter.formatIndian(lineTotal),
                  style: KTypography.amountSmall,
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ReceiptSummaryPanel extends StatelessWidget {
  final double subtotal;
  final double tax;
  final double total;

  const _ReceiptSummaryPanel({
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Summary',
      child: Column(
        children: [
          _SummaryRow(
              label: 'Taxable',
              value: CurrencyFormatter.formatIndian(subtotal)),
          _SummaryRow(label: 'GST', value: CurrencyFormatter.formatIndian(tax)),
          const Divider(height: 28),
          _SummaryRow(
              label: 'Total',
              value: CurrencyFormatter.formatIndian(total),
              bold: true),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String title;
  final String value;

  const _TextBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: KTypography.labelMedium),
          KSpacing.vGapXs,
          Text(value, style: KTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold ? KTypography.labelLarge : KTypography.bodyMedium),
          Text(value,
              style: bold ? KTypography.amountMedium : KTypography.amountSmall),
        ],
      ),
    );
  }
}
