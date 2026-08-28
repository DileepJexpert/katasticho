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
import '../data/credit_note_providers.dart';
import '../data/credit_note_repository.dart';

class CreditNoteDetailScreen extends ConsumerWidget {
  final String creditNoteId;

  const CreditNoteDetailScreen({super.key, required this.creditNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cnAsync = ref.watch(creditNoteDetailProvider(creditNoteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Note Details'),
        actions: [
          cnAsync.whenOrNull(
                data: (data) {
                  final cn =
                      (data['data'] ?? data) as Map<String, dynamic>;
                  final status = cn['status'] as String? ?? '';
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value),
                    itemBuilder: (context) => [
                      if (status == 'DRAFT')
                        const PopupMenuItem(
                            value: 'issue',
                            child: Text('Issue Credit Note')),
                      if (status == 'PENDING_APPROVAL')
                        const PopupMenuItem(
                            value: 'approvals',
                            child: Text('Open Approval Inbox')),
                      const PopupMenuItem(
                          value: 'pdf', child: Text('Download PDF')),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: cnAsync.when(
        loading: () => const KLoading(message: 'Loading credit note...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load credit note',
          onRetry: () =>
              ref.invalidate(creditNoteDetailProvider(creditNoteId)),
        ),
        data: (data) {
          final cn = (data['data'] ?? data) as Map<String, dynamic>;
          return _CreditNoteDetailBody(creditNote: cn);
        },
      ),
      bottomNavigationBar: cnAsync.whenOrNull(
        data: (data) {
          final cn = (data['data'] ?? data) as Map<String, dynamic>;
          final status = cn['status'] as String? ?? '';

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
                child: KButton(
                  label: 'Issue Credit Note',
                  icon: Icons.send,
                  fullWidth: true,
                  onPressed: () => _issueConfirmation(context, ref),
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
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'issue':
        _issueConfirmation(context, ref);
        break;
      case 'approvals':
        if (context.mounted) context.push(Routes.approvals);
        break;
      case 'pdf':
        if (context.mounted) {
          final cnAsync = ref.read(creditNoteDetailProvider(creditNoteId));
          cnAsync.whenData((data) {
            final cn = (data['data'] ?? data) as Map<String, dynamic>;
            final number = cn['creditNoteNumber'] as String? ?? 'credit-note';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KPdfPreviewScreen(
                  title: number,
                  pdfEndpoint: ApiConfig.creditNotePdf(creditNoteId),
                  fileName: '$number.pdf',
                ),
              ),
            );
          });
        }
        break;
    }
  }

  void _issueConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Credit Note?'),
        content: const Text(
          'This will post the reversal journal entry and reduce the customer balance. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(creditNoteRepositoryProvider);
                final result = await repo.issueCreditNote(creditNoteId);
                ref.invalidate(creditNoteDetailProvider(creditNoteId));
                ref.invalidate(creditNoteListProvider);
                if (context.mounted) {
                  final issued =
                      (result['data'] ?? result) as Map<String, dynamic>;
                  final newStatus = issued['status'] as String? ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newStatus == 'PENDING_APPROVAL'
                          ? 'Credit note sent for approval'
                          : 'Credit note issued successfully'),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to issue credit note')),
                  );
                }
              }
            },
            child: const Text('Issue'),
          ),
        ],
      ),
    );
  }
}

class _CreditNoteDetailBody extends StatelessWidget {
  final Map<String, dynamic> creditNote;

  const _CreditNoteDetailBody({required this.creditNote});

  @override
  Widget build(BuildContext context) {
    final status = creditNote['status'] as String? ?? 'DRAFT';
    final creditNoteNumber =
        creditNote['creditNoteNumber'] as String? ?? '--';
    final customerName =
        creditNote['contactName'] as String? ?? 'Customer';
    final invoiceNumber = creditNote['invoiceNumber'] as String?;
    final totalAmount =
        (creditNote['totalAmount'] as num?)?.toDouble() ?? 0;
    final subtotal = (creditNote['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (creditNote['taxAmount'] as num?)?.toDouble() ?? 0;
    final reason = creditNote['reason'] as String? ?? '--';
    final lines = (creditNote['lines'] as List?) ?? [];

    return DefaultTabController(
      length: 2,
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
                      child: Text(creditNoteNumber, style: KTypography.mono(fontSize: 20, fontWeight: FontWeight.w600)),
                    ),
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapSm,
                Text(customerName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                KMoney(
                  totalAmount,
                  size: KMoneySize.large,
                  style: const TextStyle(color: KColors.error),
                ),
              ],
            ),
          ),

          if (status == 'PENDING_APPROVAL')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KSpacing.md),
              color: KColors.warningLight,
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 20, color: KColors.warning),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      'This credit note is pending approval before it can be issued.',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Line Items'),
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
                          label: 'Credit Note #',
                          valueWidget: Text(creditNoteNumber, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        KDetailRow(
                          label: 'Customer',
                          value: customerName,
                        ),
                        if (invoiceNumber != null)
                          KDetailRow(
                            label: 'Against Invoice',
                            valueWidget: Text(invoiceNumber, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        KDetailRow(
                          label: 'Date',
                          value: creditNote['creditNoteDate'] as String? ??
                              '--',
                        ),
                        KDetailRow(
                          label: 'Reason',
                          value: reason,
                        ),
                        KDetailRow(
                          label: 'Place of Supply',
                          value:
                              creditNote['placeOfSupply'] as String? ?? '--',
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Subtotal',
                          valueWidget: KMoney(subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          valueWidget: KMoney(taxAmount),
                        ),
                        KDetailRow(
                          label: 'Total',
                          valueWidget: KMoney(
                            totalAmount,
                            style: const TextStyle(color: KColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Line Items tab
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
                          final gstRate =
                              (line['gstRate'] as num?)?.toDouble() ?? 0;
                          final hsnCode =
                              line['hsnCode'] as String?;

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
                                      child: Text(desc,
                                          style:
                                              KTypography.labelLarge),
                                    ),
                                    KMoney(lineTotal,
                                        size: KMoneySize.small),
                                  ],
                                ),
                                KSpacing.vGapXs,
                                Text(
                                  '${qty.toStringAsFixed(0)} x ${CurrencyFormatter.formatIndian(price)}'
                                  ' @ ${gstRate.toStringAsFixed(0)}% GST',
                                  style: KTypography.bodySmall,
                                ),
                                if (hsnCode != null &&
                                    hsnCode.isNotEmpty) ...[
                                  KSpacing.vGapXs,
                                  Text(
                                    'HSN: $hsnCode',
                                    style: KTypography.mono(fontSize: 12),
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
