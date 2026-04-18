import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../routing/app_router.dart';
import '../data/invoice_providers.dart';
import '../data/invoice_repository.dart';
import 'invoice_pdf_screen.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'send', child: Text('Send Invoice')),
              const PopupMenuItem(value: 'share', child: Text('Share via WhatsApp')),
              const PopupMenuItem(value: 'reminder', child: Text('Send Payment Reminder')),
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

          if (status == 'SENT' || status == 'PARTIALLY_PAID' || status == 'OVERDUE') {
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balance Due', style: KTypography.bodySmall),
                        Text(
                          CurrencyFormatter.formatIndian(balanceDue),
                          style: KTypography.amountLarge.copyWith(
                            color: KColors.error,
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
              const SnackBar(content: Text('Failed to send invoice')),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoicePdfScreen(invoice: invoice),
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
            fetchShareData: () => api.get(
              ApiConfig.invoiceWhatsAppLink(invoiceId),
            ).then((r) => r.data as Map<String, dynamic>),
          );
        }
        break;
      case 'reminder':
        if (context.mounted) {
          final api = ref.read(apiClientProvider);
          launchWhatsAppShare(
            context,
            fetchShareData: () => api.get(
              ApiConfig.invoiceWhatsAppReminder(invoiceId),
            ).then((r) => r.data as Map<String, dynamic>),
          );
        }
        break;
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
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (invoice['taxTotal'] as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice['amountPaid'] as num?)?.toDouble() ?? 0;
    final lines = (invoice['lines'] as List?) ?? [];

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Header
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
                      child: Text(invoiceNumber, style: KTypography.h2),
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
                  child: KCard(
                    child: Column(
                      children: [
                        KDetailRow(
                          label: 'Invoice Number',
                          value: invoiceNumber,
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
                          value: CurrencyFormatter.formatIndian(subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          value: CurrencyFormatter.formatIndian(tax),
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Total',
                          value: CurrencyFormatter.formatIndian(total),
                          valueStyle: KTypography.amountMedium,
                        ),
                        KDetailRow(
                          label: 'Amount Paid',
                          value: CurrencyFormatter.formatIndian(amountPaid),
                          valueStyle: KTypography.amountSmall.copyWith(
                            color: KColors.success,
                          ),
                        ),
                      ],
                    ),
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
                          final line =
                              lines[index] as Map<String, dynamic>;
                          final desc =
                              line['description'] as String? ?? 'Item';
                          final qty =
                              (line['quantity'] as num?)?.toDouble() ?? 0;
                          final price =
                              (line['unitPrice'] as num?)?.toDouble() ?? 0;
                          final lineTotal =
                              (line['lineTotal'] as num?)?.toDouble() ?? 0;

                          return KCard(
                            margin:
                                const EdgeInsets.only(bottom: KSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(desc,
                                          style: KTypography.bodyMedium),
                                      Text(
                                        '${qty.toStringAsFixed(0)} x ${CurrencyFormatter.formatIndian(price)}',
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
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: KColors.success),
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
                  Text(
                    CurrencyFormatter.formatIndian(amount),
                    style: KTypography.amountSmall.copyWith(
                      color: KColors.success,
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
