import 'package:flutter/foundation.dart';
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
                onSelected: (v) =>
                    _handleAction(context, ref, receipt, v),
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

  Future<void> _confirmReceive(BuildContext context, WidgetRef ref,
      Map<String, dynamic> receipt) async {
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

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref,
      Map<String, dynamic> receipt) async {
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
    final lines = (receipt['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(number, style: KTypography.h2),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              KSpacing.vGapXs,
              Text(supplierName, style: KTypography.bodyLarge),
              KSpacing.vGapMd,
              if (dateRaw != null)
                KDetailRow(
                    label: 'Receipt Date',
                    value: DateFormatter.display(DateTime.parse(dateRaw))),
              if (supInvNo != null && supInvNo.isNotEmpty)
                KDetailRow(label: 'Supplier Invoice', value: supInvNo),
              if (supInvDate != null && supInvDate.isNotEmpty)
                KDetailRow(
                    label: 'Supplier Inv. Date',
                    value: DateFormatter.display(DateTime.parse(supInvDate))),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Items (${lines.length})',
          child: Column(
            children: lines.map((l) {
              final desc = l['description'] as String? ?? '';
              final sku = l['itemSku'] as String? ?? '';
              final qty = (l['quantity'] as num?)?.toDouble() ?? 0;
              final uom = l['unitOfMeasure'] as String? ?? '';
              final unitPrice = (l['unitPrice'] as num?)?.toDouble() ?? 0;
              final lineTotal = (l['lineTotal'] as num?)?.toDouble() ?? 0;
              final batch = l['batchNumber'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc, style: KTypography.bodyMedium),
                          Text(
                            '${sku.isNotEmpty ? "SKU: $sku • " : ""}'
                            '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $uom × '
                            '${CurrencyFormatter.formatIndian(unitPrice)}'
                            '${batch.isNotEmpty ? " • Batch: $batch" : ""}',
                            style: KTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(lineTotal),
                      style: KTypography.amountSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Taxable',
                  value: CurrencyFormatter.formatIndian(subtotal)),
              _SummaryRow(
                  label: 'GST', value: CurrencyFormatter.formatIndian(tax)),
              const Divider(),
              _SummaryRow(
                  label: 'Total',
                  value: CurrencyFormatter.formatIndian(total),
                  bold: true),
            ],
          ),
        ),
        if (notes != null && notes.isNotEmpty) ...[
          KSpacing.vGapMd,
          KCard(
            title: 'Notes',
            child: Text(notes, style: KTypography.bodyMedium),
          ),
        ],
        if (cancelReason != null && cancelReason.isNotEmpty) ...[
          KSpacing.vGapMd,
          KCard(
            title: 'Cancellation',
            child: Text(cancelReason, style: KTypography.bodyMedium),
          ),
        ],
      ],
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
