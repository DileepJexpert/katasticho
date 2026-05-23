import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/sales_order_providers.dart';
import '../data/sales_order_repository.dart';

class SalesOrderDetailScreen extends ConsumerWidget {
  final String salesOrderId;

  const SalesOrderDetailScreen({super.key, required this.salesOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(salesOrderDetailProvider(salesOrderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Order'),
        actions: [
          orderAsync.whenOrNull(
            data: (data) {
              final order = (data['data'] ?? data) as Map<String, dynamic>;
              final status = order['status'] as String? ?? '';
              return PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleAction(context, ref, value, status),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'pdf', child: Text('Download PDF')),
                  if (status == 'DRAFT') ...[
                    const PopupMenuItem(
                        value: 'confirm', child: Text('Confirm')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: KColors.error)),
                    ),
                  ],
                  if (status == 'CONFIRMED' || status == 'BACKORDER')
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel Full Order',
                          style: TextStyle(color: KColors.error)),
                    ),
                ],
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: orderAsync.when(
        loading: () => const KLoading(message: 'Loading sales order...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load sales order',
          onRetry: () => ref.invalidate(salesOrderDetailProvider(salesOrderId)),
        ),
        data: (data) {
          final order = (data['data'] ?? data) as Map<String, dynamic>;
          return _SalesOrderDetailBody(
              order: order, salesOrderId: salesOrderId);
        },
      ),
      bottomNavigationBar: orderAsync.whenOrNull(
        data: (data) {
          final order = (data['data'] ?? data) as Map<String, dynamic>;
          final status = order['status'] as String? ?? '';

          if (status == 'DRAFT') {
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
                    const Spacer(),
                    KButton(
                      label: 'Confirm Order',
                      icon: Icons.check_circle_outline,
                      onPressed: () =>
                          _handleAction(context, ref, 'confirm', status),
                    ),
                  ],
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, String action, String status) async {
    final repo = ref.read(salesOrderRepositoryProvider);

    switch (action) {
      case 'pdf':
        if (context.mounted) {
          final orderAsync = ref.read(salesOrderDetailProvider(salesOrderId));
          orderAsync.whenData((data) {
            final order = (data['data'] ?? data) as Map<String, dynamic>;
            final number =
                order['salesOrderNumber'] as String? ?? 'sales-order';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KPdfPreviewScreen(
                  title: number,
                  pdfEndpoint: ApiConfig.salesOrderPdf(salesOrderId),
                  fileName: '$number.pdf',
                ),
              ),
            );
          });
        }
        break;
      case 'confirm':
        try {
          await repo.confirmSalesOrder(salesOrderId);
          ref.invalidate(salesOrderDetailProvider(salesOrderId));
          ref.invalidate(salesOrderListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sales order confirmed')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to confirm sales order')),
            );
          }
        }
        break;
      case 'cancel':
        _showCancelConfirmation(context, ref);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
  }

  Future<void> _showCancelConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await KDialog.confirm(
      context: context,
      title: 'Cancel Sales Order?',
      message:
          'This will cancel the sales order. This action cannot be undone.',
      confirmLabel: 'Cancel Order',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      await repo.cancelSalesOrder(salesOrderId);
      ref.invalidate(salesOrderDetailProvider(salesOrderId));
      ref.invalidate(salesOrderListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales order cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel sales order')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await KDialog.confirm(
      context: context,
      title: 'Delete Sales Order?',
      message:
          'This will permanently delete the sales order. This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      await repo.deleteSalesOrder(salesOrderId);
      ref.invalidate(salesOrderListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales order deleted')),
        );
        context.go(Routes.salesOrders);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete sales order')),
        );
      }
    }
  }
}

class _SalesOrderDetailBody extends ConsumerWidget {
  final Map<String, dynamic> order;
  final String salesOrderId;

  const _SalesOrderDetailBody({
    required this.order,
    required this.salesOrderId,
  });

  @override
  Future<void> _closeBackorderLines(
      BuildContext context, WidgetRef ref, List<String> lineIds) async {
    final reasonCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Backorder Line?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This medicine cannot be sourced. The backordered qty will be closed — customer should get it elsewhere.',
              style: KTypography.bodyMedium,
            ),
            KSpacing.vGapMd,
            KTextField(
              label: 'Reason (optional)',
              controller: reasonCtl,
              hint: 'e.g. Not available with any vendor',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Line'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      await repo.closeBackorderLines(salesOrderId, lineIds, reasonCtl.text.trim());
      ref.invalidate(salesOrderDetailProvider(salesOrderId));
      ref.invalidate(salesOrderListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backorder line closed')),
        );
      }
    } catch (e) {
      String msg = 'Failed to close line';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) msg = body['message'] as String? ?? msg;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? 'DRAFT';
    final orderNumber = order['salesOrderNumber'] as String? ?? '--';
    final customerName = order['contactName'] as String? ?? 'Customer';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (order['taxAmount'] as num?)?.toDouble() ?? 0;
    final discount = (order['discountAmount'] as num?)?.toDouble() ?? 0;
    final shippingCharge = (order['shippingCharge'] as num?)?.toDouble() ?? 0;
    final adjustment = (order['adjustment'] as num?)?.toDouble() ?? 0;
    final lines = (order['lines'] as List?) ?? [];

    final facts = [
      _InfoFact('Order date', order['orderDate'] as String? ?? '--'),
      _InfoFact('Ship by', order['expectedShipmentDate'] as String? ?? '--'),
      _InfoFact('Reference', order['referenceNumber'] as String? ?? '--'),
      _InfoFact('Delivery', order['deliveryMethod'] as String? ?? '--'),
      _InfoFact('Place of supply', order['placeOfSupply'] as String? ?? '--'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(KSpacing.radiusLg),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: wide ? 420 : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(orderNumber, style: KTypography.h2),
                            ),
                            KStatusChip(status: status),
                          ],
                        ),
                        KSpacing.vGapXs,
                        Text(customerName, style: KTypography.bodyLarge),
                      ],
                    ),
                  ),
                  _HeaderMetric(
                    label: 'Order total',
                    value: CurrencyFormatter.formatIndian(total),
                    icon: Icons.receipt_long_rounded,
                  ),
                  _HeaderMetric(
                    label: 'Items',
                    value: '${lines.length}',
                    icon: Icons.inventory_2_rounded,
                  ),
                  _HeaderMetric(
                    label: 'Tax',
                    value: CurrencyFormatter.formatIndian(tax),
                    icon: Icons.percent_rounded,
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _FactsPanel(facts: facts),
                        KSpacing.vGapMd,
                        _SalesOrderItemsPanel(
                          lines: lines,
                          dense: true,
                          status: status,
                          onCloseLines: (ids) =>
                              _closeBackorderLines(context, ref, ids),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.hGapMd,
                  SizedBox(
                    width: 340,
                    child: _TotalsPanel(
                      subtotal: subtotal,
                      discount: discount,
                      tax: tax,
                      shippingCharge: shippingCharge,
                      adjustment: adjustment,
                      total: total,
                      notes: order['notes'] as String?,
                      terms: order['terms'] as String?,
                    ),
                  ),
                ],
              )
            else ...[
              _FactsPanel(facts: facts),
              KSpacing.vGapMd,
              _SalesOrderItemsPanel(
                lines: lines,
                status: status,
                onCloseLines: (ids) =>
                    _closeBackorderLines(context, ref, ids),
              ),
              KSpacing.vGapMd,
              _TotalsPanel(
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                shippingCharge: shippingCharge,
                adjustment: adjustment,
                total: total,
                notes: order['notes'] as String?,
                terms: order['terms'] as String?,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _InfoFact {
  final String label;
  final String value;
  _InfoFact(this.label, this.value);
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelSmall),
                Text(value, style: KTypography.amountSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactsPanel extends StatelessWidget {
  final List<_InfoFact> facts;
  const _FactsPanel({required this.facts});

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Order Information',
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: facts
            .map((f) => SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label, style: KTypography.labelSmall),
                      const SizedBox(height: 2),
                      Text(f.value, style: KTypography.bodyMedium),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SalesOrderItemsPanel extends StatelessWidget {
  final List<dynamic> lines;
  final bool dense;
  final String status;
  final void Function(List<String> lineIds)? onCloseLines;
  const _SalesOrderItemsPanel({
    required this.lines,
    this.dense = false,
    this.status = '',
    this.onCloseLines,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const KEmptyState(icon: Icons.list_alt, title: 'No line items');
    }
    return KCard(
      title: 'Items (${lines.length})',
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: dense ? 48 : 56,
            dataRowMaxHeight: dense ? 58 : 68,
            columnSpacing: 22,
            horizontalMargin: 16,
            columns: [
              const DataColumn(label: Text('Item')),
              const DataColumn(label: Text('Qty'), numeric: true),
              const DataColumn(label: Text('Rate'), numeric: true),
              const DataColumn(label: Text('Shipped'), numeric: true),
              const DataColumn(label: Text('Invoiced'), numeric: true),
              const DataColumn(label: Text('Backordered'), numeric: true),
              const DataColumn(label: Text('Amount'), numeric: true),
              if (status == 'BACKORDER' && onCloseLines != null)
                const DataColumn(label: Text('')),
            ],
            rows: lines.map((raw) {
              final line = raw as Map<String, dynamic>;
              final itemName = line['itemName'] as String? ??
                  line['description'] as String? ??
                  'Item';
              final desc = line['description'] as String? ?? '';
              final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
              final shippedQty =
                  (line['quantityShipped'] as num?)?.toDouble() ?? 0;
              final invoicedQty =
                  (line['quantityInvoiced'] as num?)?.toDouble() ?? 0;
              final backorderedQty =
                  (line['quantityBackordered'] as num?)?.toDouble() ?? 0;
              final lineId = line['id'] as String? ?? '';
              final unit = line['unit'] as String? ?? '';
              final rate = (line['rate'] as num?)?.toDouble() ?? 0;
              final amount = (line['amount'] as num?)?.toDouble() ??
                  (line['lineTotal'] as num?)?.toDouble() ??
                  0;
              return DataRow(cells: [
                DataCell(SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KTypography.labelMedium),
                      if (desc.isNotEmpty && desc != itemName)
                        Text(desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                )),
                DataCell(Text(_qty(qty, unit))),
                DataCell(Text(CurrencyFormatter.formatIndian(rate))),
                DataCell(Text(_qty(shippedQty, ''))),
                DataCell(Text(_qty(invoicedQty, ''))),
                DataCell(backorderedQty > 0
                    ? Text(_qty(backorderedQty, ''),
                        style: TextStyle(
                            color: KColors.warning,
                            fontWeight: FontWeight.w600))
                    : const Text('0')),
                DataCell(Text(CurrencyFormatter.formatIndian(amount),
                    style: KTypography.amountSmall)),
                if (status == 'BACKORDER' && onCloseLines != null)
                  DataCell(backorderedQty > 0
                      ? TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: KColors.error,
                              padding: EdgeInsets.zero),
                          onPressed: () => onCloseLines!([lineId]),
                          child: const Text('Close',
                              style: TextStyle(fontSize: 12)),
                        )
                      : const SizedBox()),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _qty(double value, String unit) {
    final text =
        value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return unit.isEmpty ? text : '$text $unit';
  }
}

class _TotalsPanel extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double tax;
  final double shippingCharge;
  final double adjustment;
  final double total;
  final String? notes;
  final String? terms;

  const _TotalsPanel({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.shippingCharge,
    required this.adjustment,
    required this.total,
    this.notes,
    this.terms,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Summary',
      child: Column(
        children: [
          _AmountRow(label: 'Subtotal', value: subtotal),
          _AmountRow(label: 'Discount', value: discount),
          _AmountRow(label: 'GST', value: tax),
          _AmountRow(label: 'Shipping', value: shippingCharge),
          _AmountRow(label: 'Adjustment', value: adjustment),
          const Divider(height: 24),
          _AmountRow(label: 'Total', value: total, emphasized: true),
          if ((notes ?? '').isNotEmpty || (terms ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            if ((notes ?? '').isNotEmpty)
              _TextBlock(label: 'Notes', value: notes!),
            if ((terms ?? '').isNotEmpty) ...[
              KSpacing.vGapSm,
              _TextBlock(label: 'Terms', value: terms!),
            ],
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: emphasized
                    ? KTypography.labelLarge
                    : KTypography.bodyMedium),
          ),
          Text(
            CurrencyFormatter.formatIndian(value),
            style:
                emphasized ? KTypography.amountMedium : KTypography.amountSmall,
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String value;
  const _TextBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.labelSmall),
          const SizedBox(height: 3),
          Text(value, style: KTypography.bodySmall),
        ],
      ),
    );
  }
}
