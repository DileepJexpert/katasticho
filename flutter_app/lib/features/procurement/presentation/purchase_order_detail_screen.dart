import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/workflow/workflow_hint_resolver.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/purchase_order_repository.dart';
import 'stock_receipt_create_screen.dart';

class PurchaseOrderDetailScreen extends ConsumerWidget {
  final String poId;

  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poAsync = ref.watch(purchaseOrderDetailProvider(poId));

    return Scaffold(
      appBar: AppBar(
        title: poAsync.maybeWhen(
          data: (po) => Text(po['poNumber'] as String? ?? 'Purchase Order'),
          orElse: () => const Text('Purchase Order'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.purchaseOrders),
        ),
        actions: [
          poAsync.maybeWhen(
            data: (po) {
              final status = po['status'] as String? ?? '';
              if (status == 'CANCELLED' || status == 'RECEIVED') {
                return const SizedBox();
              }
              // P2P workflow shortcuts (backend: PurchaseOrderService.createGrnFromPo
              // / createBillFromPo, commit 24a9643). Only available on a SENT
              // or PARTIALLY_RECEIVED PO — DRAFT POs aren't a source of truth
              // yet, CANCELLED/RECEIVED are terminal. We treat 'PARTIAL' as
              // the partially-received status the rest of this screen already
              // gates on.
              final canDraftDownstream =
                  status == 'SENT' || status == 'PARTIAL';
              return PopupMenuButton<String>(
                onSelected: (v) => _handleAction(context, ref, po, v),
                itemBuilder: (_) => [
                  if (canDraftDownstream)
                    const PopupMenuItem(
                      value: 'create-grn',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.local_shipping_outlined),
                        title: Text('Create GRN from this PO'),
                        subtitle: Text(
                          'Drafts a goods receipt with remaining qty',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  if (canDraftDownstream)
                    const PopupMenuItem(
                      value: 'create-bill',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.receipt_outlined),
                        title: Text('Create Bill from this PO'),
                        subtitle: Text(
                          'Drafts a vendor bill linked to this PO',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  if (canDraftDownstream)
                    const PopupMenuItem(
                      value: 'scan-grn',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.document_scanner_outlined),
                        title: Text('Scan invoice → draft GRN'),
                        subtitle: Text(
                          'Vision OCR of supplier challan, matched to PO lines',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  if (status == 'DRAFT' || status == 'SENT')
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel PO',
                          style: TextStyle(color: KColors.error)),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: poAsync.when(
        loading: () => const KLoading(message: 'Loading purchase order...'),
        error: (err, st) {
          debugPrint('[PODetail] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load purchase order',
            onRetry: () => ref.invalidate(purchaseOrderDetailProvider(poId)),
          );
        },
        data: (po) => _PoBody(po: po),
      ),
      bottomNavigationBar: poAsync.whenOrNull(
        data: (po) {
          final status = po['status'] as String? ?? '';
          final canSend = status == 'DRAFT';
          final canReceive = status == 'SENT' || status == 'PARTIAL';

          if (!canSend && !canReceive) return null;

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
                            (po['totalAmount'] as num?)?.toDouble() ?? 0),
                        style: KTypography.amountLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (canSend) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KButton(
                        label: 'Edit',
                        variant: KButtonVariant.outlined,
                        icon: Icons.edit_outlined,
                        onPressed: () => context.go(
                          '/purchase-orders/$poId/edit',
                        ),
                      ),
                    ),
                    KButton(
                      label: 'Send to Supplier',
                      icon: Icons.send_outlined,
                      onPressed: () => _confirmSend(context, ref, po),
                    ),
                  ],
                  if (canReceive)
                    KButton(
                      label: 'Create Goods Receipt',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => _navigateToReceive(context, po),
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
      Map<String, dynamic> po, String action) async {
    if (action == 'cancel') {
      await _confirmCancel(context, ref, po);
    } else if (action == 'create-grn') {
      await _createGrnFromPo(context, ref, po);
    } else if (action == 'create-bill') {
      await _createBillFromPo(context, ref, po);
    } else if (action == 'scan-grn') {
      await _scanGrnFromPo(context, ref, po);
    }
  }

  /// Photo-to-GRN: pick an image (camera/gallery), POST to /ai/grn-drafts/scan
  /// to OCR it, then POST to /ai/grn-drafts with the PO id so each scan line
  /// is fuzzy-matched against this PO's lines. Navigates to the drafted GRN
  /// on success; surfaces backend error messages on failure.
  Future<void> _scanGrnFromPo(BuildContext context, WidgetRef ref,
      Map<String, dynamic> po) async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 2048,
      );
    } catch (_) {
      // Camera unavailable (desktop / web) — fall back to gallery silently.
      try {
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 2048,
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(
            content: Text('Image picker unavailable: $e'),
            backgroundColor: KColors.error));
        return;
      }
    }
    if (picked == null) return;

    // Show a non-blocking "scanning…" hint — vision OCR takes a few seconds.
    messenger.showSnackBar(const SnackBar(
        content: Text('Scanning supplier invoice…'),
        duration: Duration(seconds: 4)));

    try {
      final bytes = await picked.readAsBytes();
      final mediaType = (picked.mimeType == null || picked.mimeType!.isEmpty)
          ? 'image/jpeg'
          : picked.mimeType!;
      final base64Image = base64Encode(bytes);
      final api = ref.read(apiClientProvider);

      // 1) OCR the image.
      final scanRes = await api.post(
        ApiConfig.aiGrnDraftScan,
        data: {'base64Image': base64Image, 'mediaType': mediaType},
      );
      final scanBody = scanRes.data;
      final scan = (scanBody is Map && scanBody['data'] is Map)
          ? (scanBody['data'] as Map).cast<String, dynamic>()
          : (scanBody as Map).cast<String, dynamic>();
      final lines = (scan['lines'] as List?) ?? const [];

      // 2) Draft the GRN — pass the PO id so the matcher binds lines.
      final draftRes = await api.post(
        ApiConfig.aiGrnDrafts,
        data: {
          'purchaseOrderId': po['id']?.toString(),
          'supplierName': scan['supplierName'],
          'vendorBillNumber': scan['invoiceNumber'],
          'confidence': scan['confidence'],
          'lines': lines,
        },
      );
      final draftBody = draftRes.data;
      final draft = (draftBody is Map && draftBody['data'] is Map)
          ? (draftBody['data'] as Map).cast<String, dynamic>()
          : (draftBody as Map).cast<String, dynamic>();
      final grnId = draft['grnId']?.toString();
      final unmatched = (draft['unmatchedCount'] as num?)?.toInt() ?? 0;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(
          'Draft GRN created${unmatched > 0
              ? ' — $unmatched line(s) need review'
              : ''}')));
      if (grnId != null && context.mounted) {
        context.go('/stock-receipts/$grnId');
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Photo-to-GRN failed';
      if (body is Map) {
        msg = body['message'] as String? ?? body['error'] as String? ?? msg;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error));
    } catch (e) {
      debugPrint('[PODetail] photo-to-GRN failed: $e');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text('Photo-to-GRN failed: $e'),
          backgroundColor: KColors.error));
    }
  }

  /// POST /api/v1/purchase-orders/{id}/create-grn — drafts a Stock Receipt
  /// with one line per remaining PO line, then navigates to its detail screen.
  Future<void> _createGrnFromPo(BuildContext context, WidgetRef ref,
      Map<String, dynamic> po) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(apiClientProvider)
          .post(ApiConfig.createGrnFromPo(po['id']?.toString() ?? ''));
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map).cast<String, dynamic>();
      final grnId = payload['id']?.toString();
      ref.invalidate(purchaseOrderDetailProvider(poId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Draft GRN created')),
      );
      if (grnId != null && context.mounted) {
        context.go('/stock-receipts/$grnId');
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Failed to create GRN';
      if (body is Map) {
        msg = body['message'] as String? ?? body['error'] as String? ?? msg;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } catch (e) {
      debugPrint('[PODetail] create GRN failed: $e');
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Failed to create GRN'),
            backgroundColor: KColors.error),
      );
    }
  }

  /// POST /api/v1/purchase-orders/{id}/create-bill — drafts a Purchase Bill
  /// keyed to the PO. Fails with PO_NO_VENDOR_CONTACT when the supplier has
  /// no matching contact yet.
  Future<void> _createBillFromPo(BuildContext context, WidgetRef ref,
      Map<String, dynamic> po) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(apiClientProvider)
          .post(ApiConfig.createBillFromPo(po['id']?.toString() ?? ''));
      final data = res.data;
      final payload = (data is Map && data['data'] is Map)
          ? data['data'] as Map<String, dynamic>
          : (data as Map).cast<String, dynamic>();
      final billId = payload['id']?.toString();
      ref.invalidate(purchaseOrderDetailProvider(poId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Draft bill created')),
      );
      if (billId != null && context.mounted) {
        context.go('/bills/$billId');
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Failed to create bill';
      if (body is Map) {
        msg = body['message'] as String? ?? body['error'] as String? ?? msg;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } catch (e) {
      debugPrint('[PODetail] create bill failed: $e');
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Failed to create bill'),
            backgroundColor: KColors.error),
      );
    }
  }

  Future<void> _confirmSend(
      BuildContext context, WidgetRef ref, Map<String, dynamic> po) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to Supplier?'),
        content: const Text(
          'This will mark the PO as SENT. The supplier will be notified once you share the PO document.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(purchaseOrderRepositoryProvider);
      await repo.sendPO(po['id']?.toString() ?? '');
      ref.invalidate(purchaseOrderDetailProvider(poId));
      ref.invalidate(purchaseOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase order sent')),
        );
      }
    } catch (e) {
      debugPrint('[PODetail] send failed: $e');
      String errorMsg = 'Failed to send purchase order';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) {
          errorMsg = body['message'] as String? ??
              body['error'] as String? ??
              errorMsg;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: KColors.error),
        );
      }
    }
  }

  void _navigateToReceive(BuildContext context, Map<String, dynamic> po) {
    // A PO does not post stock. It opens a draft GRN; stock is posted only
    // from Goods Receipt detail via Receive Stock.
    context.go(
      Routes.stockReceiptCreate,
      extra: StockReceiptPrefill(
        supplier: {
          'id': po['supplierId'],
          'name': po['supplierName'] ?? 'Supplier',
        },
        items: (po['lines'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((l) => {
                  'itemId': l['itemId'],
                  'itemName': l['itemName'] ?? l['description'] ?? '',
                  'unitPrice': l['unitPrice'],
                  'suggestOrderQty':
                      ((l['quantity'] as num?)?.toDouble() ?? 0) -
                          ((l['receivedQuantity'] as num?)?.toDouble() ?? 0),
                })
            .where((l) => (l['suggestOrderQty'] as double) > 0)
            .toList(),
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, Map<String, dynamic> po) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Purchase Order?'),
        content: const Text(
          'This will cancel the purchase order. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel PO'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(purchaseOrderRepositoryProvider);
      await repo.cancelPO(po['id']?.toString() ?? '');
      ref.invalidate(purchaseOrderDetailProvider(poId));
      ref.invalidate(purchaseOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase order cancelled')),
        );
      }
    } catch (e) {
      debugPrint('[PODetail] cancel failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel purchase order'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }
}

class _PoBody extends ConsumerWidget {
  final Map<String, dynamic> po;
  const _PoBody({required this.po});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poNumber = po['poNumber'] as String? ?? '--';
    final status = po['status'] as String? ?? 'DRAFT';
    final supplierName = po['supplierName'] as String? ?? 'Unknown supplier';
    final orderDateRaw = po['orderDate'] as String?;
    final deliveryDateRaw = po['expectedDeliveryDate'] as String?;
    final notes = po['notes'] as String?;
    final total = (po['totalAmount'] as num?)?.toDouble() ?? 0;
    final lines = (po['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final auth = ref.watch(authProvider);
    final hint = WorkflowHintResolver.resolve(
      pageKey: 'purchase_order.detail',
      status: status,
      businessType: auth.businessType,
      industryCode: auth.industryCode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PoInfoPanel(
              supplierName: supplierName,
              orderDate: orderDateRaw,
              deliveryDate: deliveryDateRaw,
              notes: notes,
            ),
            KSpacing.vGapMd,
            _PoLinesPanel(lines: lines),
          ],
        );

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: KSpacing.borderRadiusLg,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: KDocumentHeader(
                title: poNumber,
                subtitle: supplierName,
                status: KStatusChip(status: status),
                amount: CurrencyFormatter.formatIndian(total),
                icon: Icons.shopping_cart_outlined,
                metrics: [
                  KDocumentHeaderMetric(
                    label: 'Lines',
                    value: lines.length.toString(),
                    icon: Icons.format_list_numbered,
                  ),
                  KDocumentHeaderMetric(
                    label: 'Total',
                    value: CurrencyFormatter.formatIndian(total),
                    icon: Icons.currency_rupee_outlined,
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            if (hint != null) ...[
              KContextHint(hint: hint),
              KSpacing.vGapMd,
            ],
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftColumn),
                  KSpacing.hGapMd,
                  SizedBox(
                    width: 340,
                    child: _PoSummaryPanel(total: total),
                  ),
                ],
              )
            else ...[
              leftColumn,
              KSpacing.vGapMd,
              _PoSummaryPanel(total: total),
            ],
          ],
        );
      },
    );
  }
}

class _PoInfoPanel extends StatelessWidget {
  final String supplierName;
  final String? orderDate;
  final String? deliveryDate;
  final String? notes;

  const _PoInfoPanel({
    required this.supplierName,
    required this.orderDate,
    required this.deliveryDate,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Order Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KDetailRow(label: 'Supplier', value: supplierName),
          if (orderDate != null)
            KDetailRow(
              label: 'Order Date',
              value: DateFormatter.display(DateTime.parse(orderDate!)),
            ),
          if (deliveryDate != null && deliveryDate!.isNotEmpty)
            KDetailRow(
              label: 'Expected Delivery',
              value: DateFormatter.display(DateTime.parse(deliveryDate!)),
            ),
          if (notes != null && notes!.isNotEmpty) ...[
            KSpacing.vGapMd,
            _TextBlock(title: 'Notes', value: notes!),
          ],
        ],
      ),
    );
  }
}

class _PoLinesPanel extends StatelessWidget {
  final List<Map<String, dynamic>> lines;

  const _PoLinesPanel({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const KCard(
        title: 'Ordered Items',
        child: KEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No items on this PO',
          subtitle: 'Items will appear here once added.',
        ),
      );
    }

    return KCard(
      title: 'Ordered Items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: KSpacing.lg,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 68,
          columns: const [
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Qty Ordered'), numeric: true),
            DataColumn(label: Text('Qty Received'), numeric: true),
            DataColumn(label: Text('Unit Price'), numeric: true),
            DataColumn(label: Text('Line Total'), numeric: true),
          ],
          rows: lines.map((line) {
            final itemName = (line['itemName'] as String? ??
                    line['description'] as String? ??
                    'Item')
                .toString();
            final desc = line['description'] as String? ?? '';
            final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
            final receivedQty =
                (line['receivedQuantity'] as num?)?.toDouble() ?? 0;
            final unitPrice = (line['unitPrice'] as num?)?.toDouble() ?? 0;
            final lineTotal = (line['lineTotal'] as num?)?.toDouble() ?? 0;

            final qtyFmt =
                qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2);
            final recFmt = receivedQty.toStringAsFixed(
                receivedQty.truncateToDouble() == receivedQty ? 0 : 2);

            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemName,
                            style: KTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                        if (desc.isNotEmpty && desc != itemName) ...[
                          KSpacing.vGapXxs,
                          Text(desc,
                              style: KTypography.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ),
                DataCell(Text(qtyFmt)),
                DataCell(Text(recFmt)),
                DataCell(Text(CurrencyFormatter.formatIndian(unitPrice))),
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

class _PoSummaryPanel extends StatelessWidget {
  final double total;

  const _PoSummaryPanel({required this.total});

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Summary',
      child: Column(
        children: [
          const Divider(height: 8),
          _SummaryRow(
            label: 'Order Total',
            value: CurrencyFormatter.formatIndian(total),
            bold: true,
          ),
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
