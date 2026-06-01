import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/workflow/workflow_hint_resolver.dart';
import '../../../routing/app_router.dart';
import '../../invoices/data/invoice_providers.dart';
import '../../sales_orders/data/sales_order_providers.dart';
import '../../sales_orders/data/sales_order_repository.dart';
import '../data/delivery_challan_providers.dart';
import '../data/delivery_challan_repository.dart';

class DeliveryChallanDetailScreen extends ConsumerWidget {
  final String challanId;

  const DeliveryChallanDetailScreen({super.key, required this.challanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challanAsync = ref.watch(deliveryChallanDetailProvider(challanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Challan'),
        actions: [
          challanAsync.whenOrNull(
            data: (data) {
              final challan = (data['data'] ?? data) as Map<String, dynamic>;
              final status = challan['status'] as String? ?? '';
              return PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleAction(context, ref, value, status),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'pdf', child: Text('Download PDF')),
                  if (status == 'DRAFT') ...[
                    const PopupMenuItem(
                        value: 'dispatch', child: Text('Dispatch')),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel',
                          style: TextStyle(color: KColors.error)),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: KColors.error)),
                    ),
                  ],
                  if (status == 'DISPATCHED')
                    const PopupMenuItem(
                        value: 'invoice',
                        child: Text('Create Sales Invoice')),
                  if (status == 'DISPATCHED')
                    const PopupMenuItem(
                        value: 'deliver', child: Text('Mark Delivered')),
                  if (status == 'DELIVERED')
                    const PopupMenuItem(
                        value: 'invoice',
                        child: Text('Create Sales Invoice')),
                ],
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: challanAsync.when(
        loading: () =>
            const KLoading(message: 'Loading delivery challan...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load delivery challan',
          onRetry: () =>
              ref.invalidate(deliveryChallanDetailProvider(challanId)),
        ),
        data: (data) {
          final challan = (data['data'] ?? data) as Map<String, dynamic>;
          return _DeliveryChallanDetailBody(
              challan: challan, challanId: challanId);
        },
      ),
      bottomNavigationBar: challanAsync.whenOrNull(
        data: (data) {
          final challan = (data['data'] ?? data) as Map<String, dynamic>;
          final status = challan['status'] as String? ?? '';

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
                      label: 'Dispatch',
                      icon: Icons.local_shipping_outlined,
                      onPressed: () =>
                          _handleAction(context, ref, 'dispatch', status),
                    ),
                  ],
                ),
              ),
            );
          }
          if (status == 'DISPATCHED' || status == 'DELIVERED') {
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
                      label: 'Create Sales Invoice',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () =>
                          _handleAction(context, ref, 'invoice', status),
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
    final repo = ref.read(deliveryChallanRepositoryProvider);

    switch (action) {
      case 'pdf':
        final detail = ref.read(deliveryChallanDetailProvider(challanId));
        detail.whenData((data) {
          final challan = (data['data'] ?? data) as Map<String, dynamic>;
          final number = challan['challanNumber'] as String? ?? 'challan';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => KPdfPreviewScreen(
                title: number,
                pdfEndpoint: ApiConfig.deliveryChallanPdf(challanId),
                fileName: '$number.pdf',
              ),
            ),
          );
        });
        break;
      case 'dispatch':
        try {
          await repo.dispatchChallan(challanId);
          ref.invalidate(deliveryChallanDetailProvider(challanId));
          ref.invalidate(deliveryChallanListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delivery challan dispatched')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to dispatch delivery challan')),
            );
          }
        }
        break;
      case 'deliver':
        try {
          await repo.deliverChallan(challanId);
          ref.invalidate(deliveryChallanDetailProvider(challanId));
          ref.invalidate(deliveryChallanListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Delivery challan marked as delivered')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to mark challan as delivered')),
            );
          }
        }
        break;
      case 'invoice':
        await _createInvoiceFromChallan(context, ref);
        break;
      case 'cancel':
        _showCancelConfirmation(context, ref);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
  }

  Future<void> _createInvoiceFromChallan(
      BuildContext context, WidgetRef ref) async {
    final detail = ref.read(deliveryChallanDetailProvider(challanId));
    final data = detail.valueOrNull;
    if (data == null) return;

    final challan = (data['data'] ?? data) as Map<String, dynamic>;
    final salesOrderId = challan['salesOrderId']?.toString();
    final lines = (challan['lines'] as List?) ?? const [];
    final invoiceLines = lines
        .whereType<Map<String, dynamic>>()
        .map((line) => {
              'soLineId': line['salesOrderLineId'],
              'quantity': line['quantity'],
            })
        .where((line) =>
            line['soLineId'] != null &&
            line['quantity'] != null &&
            ((line['quantity'] as num?)?.toDouble() ?? 0) > 0)
        .toList();

    if (salesOrderId == null || invoiceLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoiceable challan lines found')),
      );
      return;
    }

    try {
      final salesOrderRepo = ref.read(salesOrderRepositoryProvider);
      final result = await salesOrderRepo.convertToInvoice(
        salesOrderId,
        {'lines': invoiceLines},
      );
      final invoice = (result['data'] ?? result) as Map<String, dynamic>;
      final invoiceId = invoice['id']?.toString();

      ref.invalidate(deliveryChallanDetailProvider(challanId));
      ref.invalidate(deliveryChallanListProvider);
      ref.invalidate(salesOrderDetailProvider(salesOrderId));
      ref.invalidate(salesOrderListProvider);
      ref.invalidate(invoiceListProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales invoice created')),
      );
      if (invoiceId != null && invoiceId.isNotEmpty) {
        context.go('/invoices/$invoiceId');
      } else {
        context.go(Routes.invoices);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
    }
  }

  Future<void> _showCancelConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await KDialog.confirm(
      context: context,
      title: 'Cancel Delivery Challan?',
      message:
          'This will cancel the delivery challan. This action cannot be undone.',
      confirmLabel: 'Cancel Challan',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(deliveryChallanRepositoryProvider);
      await repo.cancelChallan(challanId);
      ref.invalidate(deliveryChallanDetailProvider(challanId));
      ref.invalidate(deliveryChallanListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery challan cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to cancel delivery challan')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await KDialog.confirm(
      context: context,
      title: 'Delete Delivery Challan?',
      message:
          'This will permanently delete the delivery challan. This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(deliveryChallanRepositoryProvider);
      await repo.deleteChallan(challanId);
      ref.invalidate(deliveryChallanListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery challan deleted')),
        );
        context.go('/delivery-challans');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete delivery challan')),
        );
      }
    }
  }
}

class _DeliveryChallanDetailBody extends ConsumerWidget {
  final Map<String, dynamic> challan;
  final String challanId;

  const _DeliveryChallanDetailBody({
    required this.challan,
    required this.challanId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = challan['status'] as String? ?? 'DRAFT';
    final challanNumber = challan['challanNumber'] as String? ?? '--';
    final customerName = challan['contactName'] as String? ?? 'Customer';
    final salesOrderNumber =
        challan['salesOrderNumber'] as String? ?? '--';
    final lines = (challan['lines'] as List?) ?? [];
    final auth = ref.watch(authProvider);
    final hint = WorkflowHintResolver.resolve(
      pageKey: 'delivery_challan.detail',
      status: status,
      businessType: auth.businessType,
      industryCode: auth.industryCode,
    );

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
                      child: Text(challanNumber, style: KTypography.h2),
                    ),
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapSm,
                Text('SO: $salesOrderNumber',
                    style: KTypography.bodyLarge),
                KSpacing.vGapXs,
                Text(customerName, style: KTypography.bodyMedium),
              ],
            ),
          ),

          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                KSpacing.md,
                KSpacing.md,
                0,
              ),
              child: KContextHint(hint: hint),
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
                // ── Details tab ──
                SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: KCard(
                    child: Column(
                      children: [
                        KDetailRow(
                          label: 'Challan Number',
                          value: challanNumber,
                        ),
                        KDetailRow(
                          label: 'Sales Order',
                          value: salesOrderNumber,
                        ),
                        KDetailRow(
                          label: 'Customer',
                          value: customerName,
                        ),
                        KDetailRow(
                          label: 'Challan Date',
                          value:
                              challan['challanDate'] as String? ?? '--',
                        ),
                        if ((challan['dispatchDate'] as String? ?? '')
                            .isNotEmpty)
                          KDetailRow(
                            label: 'Dispatch Date',
                            value:
                                challan['dispatchDate'] as String? ?? '--',
                          ),
                        KDetailRow(
                          label: 'Delivery Method',
                          value: challan['deliveryMethod'] as String? ??
                              '--',
                        ),
                        KDetailRow(
                          label: 'Vehicle Number',
                          value: challan['vehicleNumber'] as String? ??
                              '--',
                        ),
                        KDetailRow(
                          label: 'Tracking Number',
                          value: challan['trackingNumber'] as String? ??
                              '--',
                        ),
                        if ((challan['notes'] as String? ?? '')
                            .isNotEmpty)
                          KDetailRow(
                            label: 'Notes',
                            value: challan['notes'] as String? ?? '',
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Items tab ──
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
                          final unit =
                              line['unit'] as String? ?? '';
                          final batchNumber =
                              line['batchNumber'] as String? ?? '';

                          return KCard(
                            margin: const EdgeInsets.only(
                                bottom: KSpacing.sm),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(itemName,
                                    style: KTypography.bodyMedium),
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
                                  '${unit.isNotEmpty ? ' $unit' : ''}',
                                  style: KTypography.bodySmall,
                                ),
                                if (batchNumber.isNotEmpty) ...[
                                  KSpacing.vGapXs,
                                  Text(
                                    'Batch: $batchNumber',
                                    style: KTypography.labelSmall
                                        .copyWith(
                                            color:
                                                KColors.textSecondary),
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
