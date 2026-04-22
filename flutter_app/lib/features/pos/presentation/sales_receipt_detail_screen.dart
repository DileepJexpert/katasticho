import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
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
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 20),
            tooltip: 'Print',
            onPressed: () => _handlePrint(context, ref),
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

  Future<void> _handlePrint(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(posRepositoryProvider);
      final bytes = await repo.printReceipt(receiptId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt downloaded (${bytes.length} bytes)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: KColors.error),
      );
    }
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

class _ReceiptBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReceiptBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final receiptNumber = data['receiptNumber']?.toString() ?? '';
    final date = data['receiptDate']?.toString() ?? '';
    final contactName = data['contactName']?.toString();
    final paymentMode = data['paymentMode']?.toString() ?? '';
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (data['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final amountReceived = (data['amountReceived'] as num?)?.toDouble() ?? total;
    final changeReturned = (data['changeReturned'] as num?)?.toDouble() ?? 0;
    final upiReference = data['upiReference']?.toString();
    final notes = data['notes']?.toString();
    final lines = (data['lines'] as List?) ?? [];

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
                    fontSize: 12, fontWeight: FontWeight.w600, color: KColors.success),
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
                  _LineItem(line: lines[i] as Map<String, dynamic>),
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
                _DetailRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.formatIndian(subtotal),
                ),
                _DetailRow(
                  label: 'Tax',
                  value: CurrencyFormatter.formatIndian(taxAmount),
                ),
                const Divider(height: 16),
                _DetailRow(
                  label: 'Total',
                  value: CurrencyFormatter.formatIndian(total),
                  bold: true,
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
  const _LineItem({required this.line});

  @override
  Widget build(BuildContext context) {
    final name = line['itemName']?.toString() ?? line['description']?.toString() ?? '';
    final sku = line['itemSku']?.toString() ?? '';
    final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
    final unit = line['unit']?.toString() ?? '';
    final rate = (line['rate'] as num?)?.toDouble() ?? 0;
    final amount = (line['amount'] as num?)?.toDouble() ?? 0;
    final hsn = line['hsnCode']?.toString();

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
                '${hsn != null && hsn.isNotEmpty ? ' • HSN: $hsn' : ''}',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              if (sku.isNotEmpty)
                Text('SKU: $sku',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textSecondary, fontSize: 10)),
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
                  : KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          Text(value,
              style: bold
                  ? KTypography.amountMedium
                  : KTypography.labelMedium.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
