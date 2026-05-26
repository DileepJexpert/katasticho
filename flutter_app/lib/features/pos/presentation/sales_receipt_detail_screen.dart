import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/pos_repository.dart';
import '../data/sales_receipt_providers.dart';

class SalesReceiptDetailScreen extends ConsumerWidget {
  final String receiptId;
  const SalesReceiptDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptDetailProvider(receiptId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to sales receipts',
          onPressed: () => context.go(Routes.salesReceipts),
        ),
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            tooltip: 'View PDF',
            onPressed: () {
              final detail = ref.read(receiptDetailProvider(receiptId));
              detail.whenData((response) {
                final data = (response['data'] is Map<String, dynamic>)
                    ? response['data'] as Map<String, dynamic>
                    : response;
                final number = data['receiptNumber'] as String? ?? 'receipt';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KPdfPreviewScreen(
                      title: number,
                      pdfEndpoint: ApiConfig.salesReceiptPrint(receiptId),
                      fileName: '$number.pdf',
                      highlights: _pdfHighlights(data),
                    ),
                  ),
                );
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            tooltip: 'WhatsApp',
            onPressed: () => _handleWhatsApp(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => KErrorView(
          message: 'Failed to load receipt',
          onRetry: () => ref.invalidate(receiptDetailProvider(receiptId)),
        ),
        data: (response) {
          final data = (response['data'] is Map<String, dynamic>)
              ? response['data'] as Map<String, dynamic>
              : response;
          return _ReceiptBody(data: data);
        },
      ),
    );
  }

  Future<void> _handleWhatsApp(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(posRepositoryProvider);
      final result = await repo.getWhatsAppLink(receiptId);
      final linkData = (result['data'] is Map) ? result['data'] as Map : result;
      final link = linkData['link']?.toString() ?? linkData['url']?.toString();
      if (!context.mounted) return;
      if (link != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share link generated')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    }
  }
}

List<String> _pdfHighlights(Map<String, dynamic> data) {
  final lines = (data['lines'] as List?)?.whereType<Map>().toList() ?? const [];
  if (lines.isEmpty) return const [];
  final total = lines.length;
  int hsnCount = 0;
  int batchCount = 0;
  int expiryCount = 0;
  for (final raw in lines) {
    final line = Map<String, dynamic>.from(raw);
    if ((line['hsnCode']?.toString() ?? '').isNotEmpty) hsnCount++;
    if ((line['batchNumber']?.toString() ?? '').isNotEmpty) batchCount++;
    if ((line['batchExpiry']?.toString() ?? '').isNotEmpty) expiryCount++;
  }
  final highlights = <String>[];
  if (hsnCount > 0) highlights.add('HSN on $hsnCount/$total lines');
  if (batchCount > 0) highlights.add('Batch on $batchCount/$total lines');
  if (expiryCount > 0) highlights.add('Expiry on $expiryCount/$total lines');
  if (data['gstInvoice'] == true) highlights.add('GST invoice layout');
  return highlights;
}

class _ReceiptBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReceiptBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final receiptNumber = data['receiptNumber']?.toString() ?? '';
    final date = data['receiptDate']?.toString() ?? '';
    final contactName = data['contactName']?.toString();
    final paymentMode = data['paymentMode']?.toString() ?? '';
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final cgst = (data['cgst'] as num?)?.toDouble() ?? 0;
    final sgst = (data['sgst'] as num?)?.toDouble() ?? 0;
    final igst = (data['igst'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final amountReceived =
        (data['amountReceived'] as num?)?.toDouble() ?? total;
    final changeReturned = (data['changeReturned'] as num?)?.toDouble() ?? 0;
    final upiReference = data['upiReference']?.toString();
    final notes = data['notes']?.toString();
    final gstInvoice = data['gstInvoice'] == true;
    final lines = (data['lines'] as List?) ?? [];
    final totalDiscount = lines.fold<double>(0, (sum, raw) {
      if (raw is! Map) return sum;
      return sum + ((raw['discountAmount'] as num?)?.toDouble() ?? 0);
    });
    final mrpTotal = total + totalDiscount;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          KCard(
            title: receiptNumber,
            subtitle: date,
            action: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paymentMode,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KColors.success),
              ),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Customer', value: contactName ?? 'Walk-in'),
                if (upiReference != null && upiReference.isNotEmpty)
                  _DetailRow(label: 'UPI Ref', value: upiReference),
                if (notes != null && notes.isNotEmpty)
                  _DetailRow(label: 'Notes', value: notes),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Line items
          KCard(
            title: 'Items (${lines.length})',
            child: Column(
              children: [
                for (int i = 0; i < lines.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _LineItem(
                      line: lines[i] as Map<String, dynamic>,
                      detailed: gstInvoice),
                ],
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Totals
          KCard(
            title: 'Summary',
            child: Column(
              children: [
                if (totalDiscount > 0) ...[
                  _DetailRow(
                    label: 'MRP Total',
                    value: CurrencyFormatter.formatIndian(mrpTotal),
                  ),
                  _DetailRow(
                    label: 'Discount',
                    value: '-${CurrencyFormatter.formatIndian(totalDiscount)}',
                    valueColor: KColors.success,
                  ),
                ],
                if (gstInvoice) ...[
                  _DetailRow(
                    label: totalDiscount > 0 ? 'Taxable Subtotal' : 'Subtotal',
                    value: CurrencyFormatter.formatIndian(subtotal),
                  ),
                  if (cgst > 0)
                    _DetailRow(
                      label: 'CGST',
                      value: CurrencyFormatter.formatIndian(cgst),
                    ),
                  if (sgst > 0)
                    _DetailRow(
                      label: 'SGST',
                      value: CurrencyFormatter.formatIndian(sgst),
                    ),
                  if (igst > 0)
                    _DetailRow(
                      label: 'IGST',
                      value: CurrencyFormatter.formatIndian(igst),
                    ),
                  const Divider(height: 16),
                ],
                _DetailRow(
                  label: 'Total',
                  value: CurrencyFormatter.formatIndian(total),
                  bold: true,
                ),
                if (totalDiscount > 0)
                  _DetailRow(
                    label: 'You Saved',
                    value: CurrencyFormatter.formatIndian(totalDiscount),
                    valueColor: KColors.success,
                  ),
                if (!gstInvoice)
                  _DetailRow(
                    label: '',
                    value: '(Incl. all taxes)',
                    valueColor: KColors.textSecondary,
                  ),
                _DetailRow(
                  label: 'Received',
                  value: CurrencyFormatter.formatIndian(amountReceived),
                ),
                if (changeReturned > 0)
                  _DetailRow(
                    label: 'Change',
                    value: CurrencyFormatter.formatIndian(changeReturned),
                    valueColor: KColors.success,
                  ),
              ],
            ),
          ),
          KSpacing.vGapXl,
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final Map<String, dynamic> line;
  final bool detailed;
  const _LineItem({required this.line, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final name =
        line['itemName']?.toString() ?? line['description']?.toString() ?? '';
    final sku = line['itemSku']?.toString() ?? '';
    final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
    final unit = line['unit']?.toString() ?? '';
    final mrp = (line['mrp'] as num?)?.toDouble() ?? 0;
    final rate = (line['rate'] as num?)?.toDouble() ?? 0;
    final discountPerUnit =
        (line['discountPerUnit'] as num?)?.toDouble() ?? 0;
    final discountAmount = (line['discountAmount'] as num?)?.toDouble() ?? 0;
    final amount = (line['amount'] as num?)?.toDouble() ?? 0;
    final hsn = line['hsnCode']?.toString();
    final batchNumber = line['batchNumber']?.toString();
    final batchExpiry = line['batchExpiry']?.toString();
    final qtyText = qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2);

    if (!detailed) {
      return _RetailLineLayout(
        name: name,
        amount: amount,
        detail: '$qtyText $unit x ${CurrencyFormatter.formatIndian(rate)}',
        sku: sku,
        mrp: mrp,
        discountPerUnit: discountPerUnit,
        discountAmount: discountAmount,
        batchNumber: batchNumber,
        batchExpiry: batchExpiry,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: KTypography.labelMedium),
              const SizedBox(height: 2),
              Text(
                '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $unit x ${CurrencyFormatter.formatIndian(rate)}'
                '${hsn != null && hsn.isNotEmpty ? '  •  HSN: $hsn' : ''}',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              if (discountAmount > 0) ...[
                const SizedBox(height: 4),
                _DiscountWrap(
                  mrp: mrp,
                  discountPerUnit: discountPerUnit,
                  discountAmount: discountAmount,
                ),
              ],
              if (sku.isNotEmpty)
                Text('SKU: $sku',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textSecondary, fontSize: 10)),
              if ((batchNumber ?? '').isNotEmpty || (batchExpiry ?? '').isNotEmpty)
                Text(
                  [
                    if ((batchNumber ?? '').isNotEmpty) 'Batch: $batchNumber',
                    if ((batchExpiry ?? '').isNotEmpty) 'Exp: $batchExpiry',
                  ].join('  •  '),
                  style: KTypography.labelSmall
                      .copyWith(color: KColors.textSecondary, fontSize: 10),
                ),
            ],
          ),
        ),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: KTypography.amountSmall,
        ),
      ],
    );
  }
}

class _RetailLineLayout extends StatelessWidget {
  final String name;
  final double amount;
  final String detail;
  final String sku;
  final double mrp;
  final double discountPerUnit;
  final double discountAmount;
  final String? batchNumber;
  final String? batchExpiry;

  const _RetailLineLayout({
    required this.name,
    required this.amount,
    required this.detail,
    required this.sku,
    required this.mrp,
    required this.discountPerUnit,
    required this.discountAmount,
    this.batchNumber,
    this.batchExpiry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: KTypography.labelMedium),
              const SizedBox(height: 2),
              Text(
                detail,
                style:
                    KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (discountAmount > 0) ...[
                const SizedBox(height: 4),
                _DiscountWrap(
                  mrp: mrp,
                  discountPerUnit: discountPerUnit,
                  discountAmount: discountAmount,
                ),
              ],
              if (sku.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'SKU: $sku',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textSecondary, fontSize: 10),
                  ),
                ),
              if ((batchNumber ?? '').isNotEmpty || (batchExpiry ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if ((batchNumber ?? '').isNotEmpty) 'Batch: $batchNumber',
                      if ((batchExpiry ?? '').isNotEmpty) 'Exp: $batchExpiry',
                    ].join('  •  '),
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textSecondary, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: KTypography.amountSmall,
        ),
      ],
    );
  }
}

class _DiscountWrap extends StatelessWidget {
  final double mrp;
  final double discountPerUnit;
  final double discountAmount;

  const _DiscountWrap({
    required this.mrp,
    required this.discountPerUnit,
    required this.discountAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'MRP '),
              TextSpan(
                text: CurrencyFormatter.formatIndian(mrp),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          style: KTypography.labelSmall.copyWith(color: KColors.textSecondary),
        ),
        Text(
          'Discount ${CurrencyFormatter.formatIndian(discountPerUnit)}/unit',
          style: KTypography.labelSmall.copyWith(color: KColors.success),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: KColors.successLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Saved ${CurrencyFormatter.formatIndian(discountAmount)}',
            style: KTypography.labelSmall.copyWith(color: KColors.success),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? KTypography.labelMedium
                  : KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
          Text(value,
              style: bold
                  ? KTypography.amountMedium
                  : KTypography.labelMedium.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
