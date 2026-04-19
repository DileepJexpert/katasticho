import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                  if (status == 'DRAFT') ...[
                    const PopupMenuItem(
                        value: 'confirm', child: Text('Confirm')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: KColors.error)),
                    ),
                  ],
                  if (status == 'CONFIRMED')
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel',
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
          onRetry: () =>
              ref.invalidate(salesOrderDetailProvider(salesOrderId)),
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
      message: 'This will cancel the sales order. This action cannot be undone.',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order['status'] as String? ?? 'DRAFT';
    final orderNumber = order['salesOrderNumber'] as String? ?? '--';
    final customerName = order['contactName'] as String? ?? 'Customer';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (order['taxAmount'] as num?)?.toDouble() ?? 0;
    final discount = (order['discountAmount'] as num?)?.toDouble() ?? 0;
    final shippingCharge =
        (order['shippingCharge'] as num?)?.toDouble() ?? 0;
    final adjustment = (order['adjustment'] as num?)?.toDouble() ?? 0;
    final lines = (order['lines'] as List?) ?? [];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.md),
            color: KColors.surface,
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
                KSpacing.vGapSm,
                Text(customerName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(total),
                  style: KTypography.amountLarge,
                ),
              ],
            ),
          ),

          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Items'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: KCard(
                    child: Column(
                      children: [
                        KDetailRow(
                          label: 'Order Number',
                          value: orderNumber,
                        ),
                        KDetailRow(
                          label: 'Customer',
                          value: customerName,
                        ),
                        KDetailRow(
                          label: 'Order Date',
                          value: order['orderDate'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Expected Shipment',
                          value: order['expectedShipmentDate'] as String? ??
                              '--',
                        ),
                        KDetailRow(
                          label: 'Reference Number',
                          value:
                              order['referenceNumber'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Delivery Method',
                          value:
                              order['deliveryMethod'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Place of Supply',
                          value:
                              order['placeOfSupply'] as String? ?? '--',
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Discount',
                          value: CurrencyFormatter.formatIndian(discount),
                        ),
                        KDetailRow(
                          label: 'Subtotal',
                          value: CurrencyFormatter.formatIndian(subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          value: CurrencyFormatter.formatIndian(tax),
                        ),
                        KDetailRow(
                          label: 'Shipping Charge',
                          value: CurrencyFormatter.formatIndian(
                              shippingCharge),
                        ),
                        KDetailRow(
                          label: 'Adjustment',
                          value:
                              CurrencyFormatter.formatIndian(adjustment),
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Total',
                          value: CurrencyFormatter.formatIndian(total),
                          valueStyle: KTypography.amountMedium,
                        ),
                        if ((order['notes'] as String? ?? '').isNotEmpty)
                          KDetailRow(
                            label: 'Notes',
                            value: order['notes'] as String? ?? '',
                          ),
                        if ((order['terms'] as String? ?? '').isNotEmpty)
                          KDetailRow(
                            label: 'Terms',
                            value: order['terms'] as String? ?? '',
                          ),
                      ],
                    ),
                  ),
                ),

                lines.isEmpty
                    ? const KEmptyState(
                        icon: Icons.list_alt,
                        title: 'No line items',
                      )
                    : ListView.builder(
                        padding: KSpacing.pagePadding,
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line =
                              lines[index] as Map<String, dynamic>;
                          final itemName =
                              line['itemName'] as String? ??
                                  line['description'] as String? ??
                                  'Item';
                          final desc =
                              line['description'] as String? ?? '';
                          final qty =
                              (line['quantity'] as num?)?.toDouble() ?? 0;
                          final shippedQty =
                              (line['quantityShipped'] as num?)
                                      ?.toDouble() ??
                                  0;
                          final invoicedQty =
                              (line['quantityInvoiced'] as num?)
                                      ?.toDouble() ??
                                  0;
                          final unit =
                              line['unit'] as String? ?? '';
                          final rate =
                              (line['rate'] as num?)?.toDouble() ?? 0;
                          final discountPct =
                              (line['discountPct'] as num?)?.toDouble() ??
                                  0;
                          final taxRate =
                              (line['taxRate'] as num?)?.toDouble() ?? 0;
                          final amount =
                              (line['amount'] as num?)?.toDouble() ??
                                  (line['lineTotal'] as num?)
                                      ?.toDouble() ??
                                  0;

                          return KCard(
                            margin: const EdgeInsets.only(
                                bottom: KSpacing.sm),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(itemName,
                                          style:
                                              KTypography.bodyMedium),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatIndian(
                                          amount),
                                      style: KTypography.amountSmall,
                                    ),
                                  ],
                                ),
                                if (desc.isNotEmpty &&
                                    desc != itemName) ...[
                                  KSpacing.vGapXs,
                                  Text(desc,
                                      style: KTypography.bodySmall
                                          .copyWith(
                                              color: KColors
                                                  .textSecondary)),
                                ],
                                KSpacing.vGapXs,
                                Text(
                                  '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}'
                                  '${unit.isNotEmpty ? ' $unit' : ''}'
                                  ' x ${CurrencyFormatter.formatIndian(rate)}'
                                  '${discountPct > 0 ? ' (-${discountPct.toStringAsFixed(1)}%)' : ''}'
                                  '${taxRate > 0 ? ' +${taxRate.toStringAsFixed(1)}% tax' : ''}',
                                  style: KTypography.bodySmall,
                                ),
                                if (shippedQty > 0 ||
                                    invoicedQty > 0) ...[
                                  KSpacing.vGapXs,
                                  Row(
                                    children: [
                                      Text(
                                        'Shipped: ${shippedQty.toStringAsFixed(shippedQty.truncateToDouble() == shippedQty ? 0 : 2)}',
                                        style: KTypography.labelSmall
                                            .copyWith(
                                                color: KColors
                                                    .textSecondary),
                                      ),
                                      KSpacing.hGapMd,
                                      Text(
                                        'Invoiced: ${invoicedQty.toStringAsFixed(invoicedQty.truncateToDouble() == invoicedQty ? 0 : 2)}',
                                        style: KTypography.labelSmall
                                            .copyWith(
                                                color: KColors
                                                    .textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
