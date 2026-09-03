import 'package:dio/dio.dart';
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
import '../../../core/utils/currency_formatter.dart';
import '../../../core/workflow/workflow_hint_resolver.dart';
import '../../../routing/app_router.dart';
import '../../workflow/data/workflow_repository.dart';
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
        leading: IconButton(
          tooltip: 'Back to sales orders',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.salesOrders),
        ),
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
                      if (status == 'PENDING_APPROVAL')
                        const PopupMenuItem(
                            value: 'approvals',
                            child: Text('Open Approval Inbox')),
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
              ) ??
              const SizedBox.shrink(),
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
          final shippedStatus = order['shippedStatus'] as String? ?? '';
          final canCreateChallan =
              (status == 'CONFIRMED' ||
                      status == 'PARTIALLY_SHIPPED' ||
                      status == 'BACKORDER') &&
                  shippedStatus != 'FULLY_SHIPPED';

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
          if (canCreateChallan) {
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
                      label: 'Create Delivery Challan',
                      icon: Icons.local_shipping_outlined,
                      onPressed: () => context.go(
                        '${Routes.deliveryChallanCreate}?salesOrderId=$salesOrderId',
                      ),
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
        if (status == 'PENDING_APPROVAL') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Approve this sales order before confirming')),
            );
          }
          return;
        }
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
      case 'approvals':
        if (context.mounted) context.push(Routes.approvals);
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
      await repo.closeBackorderLines(
          salesOrderId, lineIds, reasonCtl.text.trim());
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
    // SalesOrderResponse exposes the canonical field as totalAmount.
    // Keep total as a fallback for older API payloads already cached by the app.
    final total = (order['totalAmount'] as num?)?.toDouble() ??
        (order['total'] as num?)?.toDouble() ??
        0;
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (order['taxAmount'] as num?)?.toDouble() ?? 0;
    final discount = (order['discountAmount'] as num?)?.toDouble() ?? 0;
    final shippingCharge = (order['shippingCharge'] as num?)?.toDouble() ?? 0;
    final adjustment = (order['adjustment'] as num?)?.toDouble() ?? 0;
    final lines = (order['lines'] as List?) ?? [];
    final auth = ref.watch(authProvider);
    final hint = WorkflowHintResolver.resolve(
      pageKey: 'sales_order.detail',
      status: status,
      businessType: auth.businessType,
      industryCode: auth.industryCode,
    );

    final facts = [
      _InfoFact('Order date', order['orderDate'] as String? ?? '--'),
      _InfoFact('Ship by', order['expectedShipmentDate'] as String? ?? '--'),
      _InfoFact('Reference', order['referenceNumber'] as String? ?? '--'),
      _InfoFact('Delivery', order['deliveryMethod'] as String? ?? '--'),
      _InfoFact('Place of supply', order['placeOfSupply'] as String? ?? '--'),
      _InfoFact('Fulfilment warehouse',
          order['warehouseName'] as String? ?? '--'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: KSpacing.borderRadiusLg,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: KDocumentHeader(
                title: orderNumber,
                subtitle: customerName,
                status: KStatusChip(status: status),
                amount: CurrencyFormatter.formatIndian(total),
                icon: Icons.assignment_outlined,
                metrics: [
                  KDocumentHeaderMetric(
                    label: 'Items',
                    value: '${lines.length}',
                    icon: Icons.inventory_2_rounded,
                  ),
                  KDocumentHeaderMetric(
                    label: 'Tax',
                    value: CurrencyFormatter.formatIndian(tax),
                    icon: Icons.percent_rounded,
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            if (hint != null) ...[
              KContextHint(hint: hint),
              KSpacing.vGapMd,
            ],
            if (status == 'PENDING_APPROVAL') ...[
              _PendingApprovalBanner(salesOrderId: salesOrderId),
              KSpacing.vGapMd,
            ],
            _ApprovalHistoryPanel(salesOrderId: salesOrderId),
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
                        KCustomFieldsCard(
                          entityType: 'SALES_ORDER',
                          entityId: salesOrderId,
                        ),
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
              KCustomFieldsCard(
                entityType: 'SALES_ORDER',
                entityId: salesOrderId,
              ),
              KSpacing.vGapMd,
              _SalesOrderItemsPanel(
                lines: lines,
                status: status,
                onCloseLines: (ids) => _closeBackorderLines(context, ref, ids),
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

class _PendingApprovalBanner extends ConsumerStatefulWidget {
  final String salesOrderId;

  const _PendingApprovalBanner({required this.salesOrderId});

  @override
  ConsumerState<_PendingApprovalBanner> createState() =>
      _PendingApprovalBannerState();
}

class _PendingApprovalBannerState
    extends ConsumerState<_PendingApprovalBanner> {
  bool _deciding = false;

  Future<void> _decide(String approvalId, bool approve) async {
    final note = await _promptNote(approve);
    if (!mounted) return;
    setState(() => _deciding = true);
    try {
      final repo = ref.read(workflowRepositoryProvider);
      if (approve) {
        await repo.approve(approvalId, note: note);
      } else {
        await repo.reject(approvalId, note: note);
      }
      ref.invalidate(approvalRequestsProvider);
      ref.invalidate(approvalRequestForDocumentProvider(
          'SALES_ORDER|${widget.salesOrderId}'));
      ref.invalidate(approvalHistoryForDocumentProvider(
          'SALES_ORDER|${widget.salesOrderId}'));
      ref.invalidate(salesOrderDetailProvider(widget.salesOrderId));
      ref.invalidate(salesOrderListProvider);
      _showSnack(approve ? 'Sales order approved' : 'Sales order rejected');
    } catch (e) {
      _showSnack(ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  Future<String?> _promptNote(bool approve) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve sales order' : 'Reject sales order'),
        content: TextField(
          controller: controller,
          autofocus: !approve,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: !approve
                ? FilledButton.styleFrom(backgroundColor: KColors.error)
                : null,
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final approvalAsync = ref.watch(approvalRequestForDocumentProvider(
        'SALES_ORDER|${widget.salesOrderId}'));
    final approval = approvalAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColors.warning.withValues(alpha: 0.10),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: KColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_actions_outlined, color: KColors.warning),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending approval',
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This sales order cannot be confirmed, dispatched, or invoiced until the approval workflow is completed.',
                  style: KTypography.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (approval != null) ...[
                FilledButton.icon(
                  onPressed:
                      _deciding ? null : () => _decide(approval.id, true),
                  icon: _deciding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
                TextButton.icon(
                  onPressed:
                      _deciding ? null : () => _decide(approval.id, false),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(foregroundColor: KColors.error),
                ),
              ],
              TextButton.icon(
                onPressed: () => context.push(Routes.approvals),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(approval == null ? 'Approvals' : 'Inbox'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalHistoryPanel extends ConsumerWidget {
  final String salesOrderId;

  const _ApprovalHistoryPanel({required this.salesOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      approvalHistoryForDocumentProvider('SALES_ORDER|$salesOrderId'),
    );

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.md),
          child: KCard(
            title: 'Approval History',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final request in history.requests) ...[
                  _ApprovalRequestTimelineRow(request: request),
                  const SizedBox(height: 8),
                ],
                for (final decision in history.decisions) ...[
                  _ApprovalDecisionTimelineRow(decision: decision),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApprovalRequestTimelineRow extends StatelessWidget {
  final ApprovalRequest request;

  const _ApprovalRequestTimelineRow({required this.request});

  @override
  Widget build(BuildContext context) {
    return _TimelineRow(
      icon: Icons.pending_actions_outlined,
      color: KColors.warning,
      title: '${_approvalLabel(request.status)} approval requested',
      subtitle: request.triggerReason.isEmpty
          ? 'Step ${request.currentStep}'
          : request.triggerReason,
      trailing: request.requestedAt,
    );
  }
}

class _ApprovalDecisionTimelineRow extends StatelessWidget {
  final ApprovalDecision decision;

  const _ApprovalDecisionTimelineRow({required this.decision});

  @override
  Widget build(BuildContext context) {
    final approved = decision.decision == 'APPROVED';
    return _TimelineRow(
      icon: approved ? Icons.check_circle_outline : Icons.cancel_outlined,
      color: approved ? KColors.success : KColors.error,
      title:
          '${_approvalLabel(decision.decision)} at step ${decision.stepNumber}',
      subtitle: (decision.note ?? '').isEmpty ? 'No note' : decision.note!,
      trailing: decision.decidedAt,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: KTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

String _approvalLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _InfoFact {
  final String label;
  final String value;
  _InfoFact(this.label, this.value);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final itemWidth = compact ? 210.0 : 260.0;
            final minWidth = compact ? 860.0 : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: dense ? 44 : 50,
                  dataRowMaxHeight: dense ? 54 : 62,
                  columnSpacing: compact ? 12 : 16,
                  horizontalMargin: compact ? 10 : 12,
                  headingTextStyle: KTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  dataTextStyle: KTypography.bodySmall,
                  columns: [
                    const DataColumn(label: Text('Item')),
                    const DataColumn(label: Text('Qty'), numeric: true),
                    const DataColumn(label: Text('Rate'), numeric: true),
                    const DataColumn(label: Text('Shipped'), numeric: true),
                    const DataColumn(label: Text('Invoiced'), numeric: true),
                    const DataColumn(label: Text('Backorder'), numeric: true),
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
                        width: itemWidth,
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
                      DataCell(KMoney(rate)),
                      DataCell(Text(_qty(shippedQty, ''))),
                      DataCell(Text(_qty(invoicedQty, ''))),
                      DataCell(backorderedQty > 0
                          ? Text(_qty(backorderedQty, ''),
                              style: TextStyle(
                                  color: KColors.warning,
                                  fontWeight: FontWeight.w600))
                          : const Text('0')),
                      DataCell(KMoney(amount)),
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
            );
          },
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
