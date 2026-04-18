import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
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
          PopupMenuButton<String>(
            onSelected: (value) => _handleAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'issue', child: Text('Issue Credit Note')),
              const PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
            ],
          ),
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
      case 'pdf':
        // PDF placeholder
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
                await repo.issueCreditNote(creditNoteId);
                ref.invalidate(creditNoteDetailProvider(creditNoteId));
                ref.invalidate(creditNoteListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Credit note issued successfully')),
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
                      child: Text(creditNoteNumber, style: KTypography.h2),
                    ),
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapSm,
                Text(customerName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(totalAmount),
                  style: KTypography.amountLarge.copyWith(
                    color: KColors.error,
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
                          value: creditNoteNumber,
                        ),
                        KDetailRow(
                          label: 'Customer',
                          value: customerName,
                        ),
                        if (invoiceNumber != null)
                          KDetailRow(
                            label: 'Against Invoice',
                            value: invoiceNumber,
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
                          value: CurrencyFormatter.formatIndian(subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          value: CurrencyFormatter.formatIndian(taxAmount),
                        ),
                        KDetailRow(
                          label: 'Total',
                          value:
                              CurrencyFormatter.formatIndian(totalAmount),
                          valueStyle: KTypography.amountMedium.copyWith(
                            color: KColors.error,
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
                                    Text(
                                      CurrencyFormatter.formatIndian(
                                          lineTotal),
                                      style: KTypography.amountSmall,
                                    ),
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
                                    style: KTypography.bodySmall,
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
