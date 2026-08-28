import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../routing/app_router.dart';
import '../data/invoice_providers.dart';
import '../data/invoice_repository.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));
    final loadedStatus = ((invoiceAsync.valueOrNull?['data'] ??
            invoiceAsync.valueOrNull) as Map?)?['status'] as String?;
    final isDraft = loadedStatus == 'DRAFT';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to invoices',
          onPressed: () => context.go(Routes.invoices),
        ),
        title: const Text('Invoice Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, ref, value),
            itemBuilder: (context) => [
              if (isDraft)
                const PopupMenuItem(value: 'edit', child: Text('Edit Invoice')),
              const PopupMenuItem(value: 'send', child: Text('Send Invoice')),
              const PopupMenuItem(
                  value: 'share', child: Text('Share via WhatsApp')),
              const PopupMenuItem(
                  value: 'wa_send', child: Text('Send via WhatsApp (PDF)')),
              const PopupMenuItem(
                  value: 'reminder', child: Text('Send Payment Reminder')),
              const PopupMenuItem(
                  value: 'payment_link', child: Text('Get Razorpay Payment Link')),
              const PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel Invoice',
                    style: TextStyle(color: KColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const KLoading(message: 'Loading invoice...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load invoice',
          onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
        data: (data) {
          final invoice = (data['data'] ?? data) as Map<String, dynamic>;
          return _InvoiceDetailBody(invoice: invoice, invoiceId: invoiceId);
        },
      ),
      bottomNavigationBar: invoiceAsync.whenOrNull(
        data: (data) {
          final invoice = (data['data'] ?? data) as Map<String, dynamic>;
          final status = invoice['status'] as String? ?? '';
          final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? 0;

          if (status == 'SENT' ||
              status == 'PARTIALLY_PAID' ||
              status == 'OVERDUE') {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balance Due', style: KTypography.bodySmall),
                        KMoney(
                          balanceDue,
                          size: KMoneySize.medium,
                          style: const TextStyle(
                            color: KColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    KButton(
                      label: 'Record Payment',
                      icon: Icons.payments,
                      variant: KButtonVariant.secondary,
                      onPressed: () => context.push('/invoices/$invoiceId/pay'),
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

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(invoiceRepositoryProvider);

    switch (action) {
      case 'edit':
        context.push('/invoices/$invoiceId/edit');
        break;
      case 'send':
        try {
          await repo.sendInvoice(invoiceId);
          ref.invalidate(invoiceDetailProvider(invoiceId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invoice sent successfully')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ApiErrorParser.message(e)),
                backgroundColor: KColors.error,
              ),
            );
          }
        }
        break;
      case 'cancel':
        _showCancelConfirmation(context, ref);
        break;
      case 'pdf':
        if (context.mounted) {
          final invoiceAsync = ref.read(invoiceDetailProvider(invoiceId));
          invoiceAsync.whenData((data) {
            final invoice = (data['data'] ?? data) as Map<String, dynamic>;
            final number = invoice['invoiceNumber'] as String? ?? 'invoice';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KPdfPreviewScreen(
                  title: number,
                  pdfEndpoint: ApiConfig.invoicePdf(invoiceId),
                  fileName: '$number.pdf',
                  highlights: _invoicePdfHighlights(invoice),
                ),
              ),
            );
          });
        }
        break;
      case 'share':
        if (context.mounted) {
          final api = ref.read(apiClientProvider);
          launchWhatsAppShare(
            context,
            fetchShareData: () => api
                .get(
                  ApiConfig.invoiceWhatsAppLink(invoiceId),
                )
                .then((r) => r.data as Map<String, dynamic>),
          );
        }
        break;
      case 'wa_send':
        if (context.mounted) {
          final api = ref.read(apiClientProvider);
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
              const SnackBar(content: Text('Sending invoice via WhatsApp...')));
          try {
            final res = await api.post(ApiConfig.whatsappSendInvoice(invoiceId));
            final body = res.data as Map<String, dynamic>;
            final row = (body['data'] ?? body) as Map<String, dynamic>;
            final status = row['status'] as String? ?? 'DONE';
            final err = row['errorMessage'] as String?;
            messenger.showSnackBar(SnackBar(
                content: Text(status == 'SENT'
                    ? 'Invoice sent on WhatsApp'
                    : 'WhatsApp $status${err != null ? ': $err' : ''}')));
          } catch (e) {
            messenger
                .showSnackBar(SnackBar(content: Text('WhatsApp send failed: $e')));
          }
        }
        break;
      case 'reminder':
        if (context.mounted) {
          final api = ref.read(apiClientProvider);
          launchWhatsAppShare(
            context,
            fetchShareData: () => api
                .get(
                  ApiConfig.invoiceWhatsAppReminder(invoiceId),
                )
                .then((r) => r.data as Map<String, dynamic>),
          );
        }
        break;
      case 'payment_link':
        _createAndShowPaymentLink(context, ref);
        break;
    }
  }

  Future<void> _createAndShowPaymentLink(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Generating Razorpay payment link...')));
      final res = await api.post(ApiConfig.invoicePaymentLink(invoiceId));
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final shortUrl = data['shortUrl']?.toString() ?? data['paymentUrl']?.toString() ?? '';
      final amt = (data['amount'] as num?)?.toDouble() ?? 0;

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Razorpay Payment Link'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Amount: ', style: KTypography.h4),
                      KMoney(amt, size: KMoneySize.medium),
                    ],
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: TextEditingController(text: shortUrl),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Payment URL',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: shortUrl));
                          messenger.showSnackBar(const SnackBar(content: Text('Copied payment link to clipboard')));
                        },
                      ),
                    ),
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Share this link directly with your customer. Once paid, the invoice will automatically settle in Katasticho via webhook.',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              KButton(
                label: 'Copy Link',
                icon: Icons.copy,
                variant: KButtonVariant.primary,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shortUrl));
                  Navigator.pop(ctx);
                  messenger.showSnackBar(const SnackBar(content: Text('Copied payment link to clipboard')));
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to generate payment link: $e'), backgroundColor: KColors.error));
      }
    }
  }

  Future<void> _showCancelConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await KDialog.confirm(
      context: context,
      title: 'Cancel Invoice?',
      message:
          'This will reverse the journal entry. This action cannot be undone.',
      confirmLabel: 'Cancel Invoice',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      await repo.cancelInvoice(invoiceId);
      ref.invalidate(invoiceDetailProvider(invoiceId));
    } catch (_) {}
  }
}

List<String> _invoicePdfHighlights(Map<String, dynamic> invoice) {
  final lines =
      (invoice['lines'] as List?)?.whereType<Map>().toList() ?? const [];
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
  return highlights;
}

class _InvoiceDetailBody extends ConsumerWidget {
  final Map<String, dynamic> invoice;
  final String invoiceId;

  const _InvoiceDetailBody({
    required this.invoice,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = invoice['status'] as String? ?? 'DRAFT';
    final invoiceNumber = invoice['invoiceNumber'] as String? ?? '--';
    final customerName = invoice['contactName'] as String? ?? 'Customer';
    final total = (invoice['totalAmount'] as num?)?.toDouble() ??
        (invoice['total'] as num?)?.toDouble() ??
        0;
    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (invoice['taxAmount'] as num?)?.toDouble() ??
        (invoice['taxTotal'] as num?)?.toDouble() ??
        0;
    final amountPaid = (invoice['amountPaid'] as num?)?.toDouble() ?? 0;
    final lines = (invoice['lines'] as List?) ?? [];

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Header
          KDocumentHeader(
            title: invoiceNumber,
            subtitle: customerName,
            status: KStatusChip(status: status),
            amount: CurrencyFormatter.formatIndian(total),
            icon: Icons.receipt_long_rounded,
          ),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Items'),
              Tab(text: 'Payments'),
              Tab(text: 'Activity'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                // Details tab
                SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: Column(
                    children: [
                      KCard(
                        child: Column(
                          children: [
                            KDetailRow(
                              label: 'Invoice Number',
                              valueWidget: Text(invoiceNumber, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            KDetailRow(
                              label: 'Customer',
                              value: customerName,
                            ),
                            KDetailRow(
                              label: 'Invoice Date',
                              value: invoice['invoiceDate'] as String? ?? '--',
                            ),
                            KDetailRow(
                              label: 'Due Date',
                              value: invoice['dueDate'] as String? ?? '--',
                            ),
                            KDetailRow(
                              label: 'Subtotal',
                              valueWidget: KMoney(subtotal),
                            ),
                            KDetailRow(
                              label: 'Tax',
                              valueWidget: KMoney(tax),
                            ),
                            const Divider(),
                            KDetailRow(
                              label: 'Total',
                              valueWidget: KMoney(total, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            KDetailRow(
                              label: 'Amount Paid',
                              valueWidget: KMoney(amountPaid, size: KMoneySize.small, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      KSpacing.vGapMd,
                      KCustomFieldsCard(
                        entityType: 'INVOICE',
                        entityId: invoiceId,
                      ),
                    ],
                  ),
                ),

                // Items tab
                lines.isEmpty
                    ? const KEmptyState(
                        icon: Icons.list_alt,
                        title: 'No line items',
                      )
                    : ListView.builder(
                        padding: KSpacing.pagePadding,
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line = lines[index] as Map<String, dynamic>;
                          final desc = line['description'] as String? ?? 'Item';
                          final qty =
                              (line['quantity'] as num?)?.toDouble() ?? 0;
                          final price =
                              (line['unitPrice'] as num?)?.toDouble() ?? 0;
                          final lineTotal =
                              (line['lineTotal'] as num?)?.toDouble() ?? 0;

                          final hsn = line['hsnCode'] as String?;
                          final batchNum = line['batchNumber'] as String?;
                          final batchExp = line['batchExpiry'] as String?;
                          final itemMrp = (line['itemMrp'] as num?)?.toDouble();

                          return KCard(
                            margin: const EdgeInsets.only(bottom: KSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(desc, style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                      KSpacing.vGapXxs,
                                      Row(
                                        children: [
                                          Text(
                                            '${qty == qty.roundToDouble() ? qty.toInt() : qty.toStringAsFixed(2)} × ',
                                            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                          ),
                                          KMoney(price, size: KMoneySize.small, style: TextStyle(color: KColors.textSecondary)),
                                        ],
                                      ),
                                      if (hsn != null && hsn.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text(
                                            'HSN $hsn',
                                            style: KTypography.mono(
                                              fontSize: 11,
                                              color: KColors.textHint,
                                            ),
                                          ),
                                        ),
                                      if (itemMrp != null && itemMrp > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              Text('MRP ', style: KTypography.caption.copyWith(color: KColors.textHint)),
                                              KMoney(itemMrp, size: KMoneySize.small, style: TextStyle(color: KColors.textHint)),
                                            ],
                                          ),
                                        ),
                                      if (batchNum != null &&
                                          batchNum.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.science_outlined,
                                                size: 13,
                                                color: KColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Batch: $batchNum${batchExp != null && batchExp.isNotEmpty ? ' · Exp: $batchExp' : ''}',
                                                style: KTypography.mono(
                                                  fontSize: 11,
                                                  color: KColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                KMoney(
                                  lineTotal,
                                  size: KMoneySize.medium,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Payments tab
                _PaymentsTab(invoiceId: invoiceId),

                // Activity tab
                KActivityTimeline(
                  entityType: 'INVOICE',
                  entityId: invoiceId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  final String invoiceId;

  const _PaymentsTab({required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoiceId));

    return paymentsAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load payments',
        onRetry: () => ref.invalidate(invoicePaymentsProvider(invoiceId)),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return const KEmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments recorded',
            subtitle: 'Payments will appear here',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final p = payments[index];
            final amount = (p['amount'] as num?)?.toDouble() ?? 0;
            final method = p['paymentMethod'] as String? ?? '--';
            final number = p['paymentNumber'] as String? ?? '';
            final date = p['paymentDate'] as String? ?? '';
            final reference = p['referenceNumber'] as String?;
            final status = p['status']?.toString() ?? 'POSTED';
            final isPendingApproval = status == 'PENDING_APPROVAL';
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    isPendingApproval
                        ? Icons.pending_actions_rounded
                        : Icons.payments,
                    color:
                        isPendingApproval ? KColors.warning : KColors.success,
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(number, style: KTypography.labelLarge),
                        Text(
                          '${_methodLabel(method)} • $date',
                          style: KTypography.bodySmall,
                        ),
                        if (reference != null && reference.isNotEmpty)
                          Text(
                            'Ref: $reference',
                            style: KTypography.bodySmall.copyWith(
                              color: KColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  KStatusChip(status: status),
                  KSpacing.hGapMd,
                  KMoney(
                    amount,
                    size: KMoneySize.small,
                    style: TextStyle(
                      color: isPendingApproval ? KColors.warning : KColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'UPI':
        return 'UPI';
      case 'CASH':
        return 'Cash';
      case 'CHEQUE':
        return 'Cheque';
      case 'CARD':
        return 'Card';
      default:
        return method;
    }
  }
}
