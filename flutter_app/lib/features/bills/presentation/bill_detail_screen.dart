import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/bill_providers.dart';
import '../data/bill_repository.dart';

class BillDetailScreen extends ConsumerWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailProvider(billId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          billAsync.whenOrNull(
                data: (data) {
                  final bill = (data['data'] ?? data) as Map<String, dynamic>;
                  final status = bill['status'] as String? ?? '';
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value, status),
                    itemBuilder: (context) => [
                      if (status == 'DRAFT')
                        const PopupMenuItem(
                            value: 'post', child: Text('Post Bill')),
                      if (status == 'DRAFT')
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Bill',
                                style: TextStyle(color: KColors.error))),
                      if (status == 'OPEN' ||
                          status == 'PARTIALLY_PAID' ||
                          status == 'OVERDUE')
                        const PopupMenuItem(
                            value: 'void',
                            child: Text('Void Bill',
                                style: TextStyle(color: KColors.error))),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: billAsync.when(
        loading: () => const KLoading(message: 'Loading bill...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load bill',
          onRetry: () => ref.invalidate(billDetailProvider(billId)),
        ),
        data: (data) {
          final bill = (data['data'] ?? data) as Map<String, dynamic>;
          return _BillDetailBody(bill: bill, billId: billId);
        },
      ),
      bottomNavigationBar: billAsync.whenOrNull(
        data: (data) {
          final bill = (data['data'] ?? data) as Map<String, dynamic>;
          final status = bill['status'] as String? ?? '';
          final balanceDue =
              (bill['balanceDue'] as num?)?.toDouble() ?? 0;

          if (status == 'OPEN' ||
              status == 'PARTIALLY_PAID' ||
              status == 'OVERDUE') {
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
                      onPressed: () =>
                          _showPaymentSheet(context, ref, bill),
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
    final repo = ref.read(billRepositoryProvider);

    switch (action) {
      case 'post':
        try {
          await repo.postBill(billId);
          ref.invalidate(billDetailProvider(billId));
          ref.invalidate(billListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bill posted — journal entry created')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to post bill')),
            );
          }
        }
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
      case 'void':
        _showVoidConfirmation(context, ref);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: const Text(
          'This will permanently delete this draft bill. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                await repo.deleteBill(billId);
                ref.invalidate(billListProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill deleted')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete bill')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showVoidConfirmation(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Bill?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will reverse the journal entry. This action cannot be undone.',
            ),
            KSpacing.vGapMd,
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why is this bill being voided?',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(billRepositoryProvider);
                final reason = reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim();
                await repo.voidBill(billId, reason: reason);
                ref.invalidate(billDetailProvider(billId));
                ref.invalidate(billListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill voided')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to void bill')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Void Bill'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> bill,
  ) {
    final balanceDue = (bill['balanceDue'] as num?)?.toDouble() ?? 0;
    final amountController =
        TextEditingController(text: balanceDue.toStringAsFixed(2));
    String paymentMethod = 'BANK_TRANSFER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: KSpacing.md,
          right: KSpacing.md,
          top: KSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record Payment', style: KTypography.h2),
            KSpacing.vGapSm,
            Text(
              'Bill: ${bill['billNumber'] ?? '--'}',
              style: KTypography.bodySmall.copyWith(
                color: KColors.textSecondary,
              ),
            ),
            KSpacing.vGapMd,
            KTextField.amount(
              label: 'Amount',
              controller: amountController,
            ),
            KSpacing.vGapMd,
            DropdownButtonFormField<String>(
              value: paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                DropdownMenuItem(value: 'CARD', child: Text('Card')),
              ],
              onChanged: (v) => paymentMethod = v ?? 'BANK_TRANSFER',
            ),
            KSpacing.vGapLg,
            KButton(
              label: 'Record Payment',
              icon: Icons.check,
              fullWidth: true,
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(billRepositoryProvider);
                  await repo.recordPayment({
                    'billId': billId,
                    'amount': double.tryParse(amountController.text) ?? 0,
                    'paymentMethod': paymentMethod,
                    'paymentDate':
                        DateTime.now().toIso8601String().split('T')[0],
                  });
                  ref.invalidate(billDetailProvider(billId));
                  ref.invalidate(billListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Payment recorded successfully')),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to record payment')),
                    );
                  }
                }
              },
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }
}

class _BillDetailBody extends ConsumerWidget {
  final Map<String, dynamic> bill;
  final String billId;

  const _BillDetailBody({required this.bill, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = bill['status'] as String? ?? 'DRAFT';
    final billNumber = bill['billNumber'] as String? ?? '--';
    final vendorName = bill['vendorName'] as String? ?? 'Vendor';
    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? totalAmount;
    final taxAmount = (bill['taxAmount'] as num?)?.toDouble() ?? 0;
    final amountPaid = (bill['amountPaid'] as num?)?.toDouble() ?? 0;
    final lines = (bill['lines'] as List?) ?? [];

    return DefaultTabController(
      length: 3,
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
                      child: Text(billNumber, style: KTypography.h2),
                    ),
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapSm,
                Text(vendorName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(totalAmount),
                  style: KTypography.amountLarge,
                ),
              ],
            ),
          ),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Lines'),
              Tab(text: 'Payments'),
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
                          label: 'Bill Number',
                          value: billNumber,
                        ),
                        KDetailRow(
                          label: 'Vendor',
                          value: vendorName,
                        ),
                        KDetailRow(
                          label: 'Vendor Bill #',
                          value: bill['vendorBillNumber'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Bill Date',
                          value: bill['billDate'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Due Date',
                          value: bill['dueDate'] as String? ?? '--',
                        ),
                        KDetailRow(
                          label: 'Place of Supply',
                          value: bill['placeOfSupply'] as String? ?? '--',
                        ),
                        if (bill['reverseCharge'] == true)
                          const KDetailRow(
                            label: 'Reverse Charge',
                            value: 'Yes',
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
                        const Divider(),
                        KDetailRow(
                          label: 'Total',
                          value: CurrencyFormatter.formatIndian(totalAmount),
                          valueStyle: KTypography.amountMedium,
                        ),
                        KDetailRow(
                          label: 'Amount Paid',
                          value: CurrencyFormatter.formatIndian(amountPaid),
                          valueStyle: KTypography.amountSmall.copyWith(
                            color: KColors.success,
                          ),
                        ),
                        if (bill['notes'] != null &&
                            (bill['notes'] as String).isNotEmpty) ...[
                          const Divider(),
                          KDetailRow(
                            label: 'Notes',
                            value: bill['notes'] as String,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Lines tab
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
                          final itemName =
                              line['itemName'] as String? ?? 'Item';
                          final description =
                              line['description'] as String? ?? '';
                          final qty =
                              (line['quantity'] as num?)?.toDouble() ?? 0;
                          final unitPrice =
                              (line['unitPrice'] as num?)?.toDouble() ?? 0;
                          final lineTotal =
                              (line['lineTotal'] as num?)?.toDouble() ?? 0;
                          final taxGroupName =
                              line['taxGroupName'] as String?;

                          return KCard(
                            margin:
                                const EdgeInsets.only(bottom: KSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(itemName,
                                              style: KTypography.bodyMedium
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                          if (description.isNotEmpty)
                                            Text(description,
                                                style: KTypography.bodySmall
                                                    .copyWith(
                                                        color: KColors
                                                            .textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatIndian(
                                          lineTotal),
                                      style: KTypography.amountSmall,
                                    ),
                                  ],
                                ),
                                KSpacing.vGapXs,
                                Row(
                                  children: [
                                    Text(
                                      '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} x ${CurrencyFormatter.formatIndian(unitPrice)}',
                                      style: KTypography.bodySmall.copyWith(
                                        color: KColors.textSecondary,
                                      ),
                                    ),
                                    if (taxGroupName != null) ...[
                                      KSpacing.hGapSm,
                                      Text(
                                        taxGroupName,
                                        style:
                                            KTypography.labelSmall.copyWith(
                                          color: KColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Payments tab
                _PaymentsTab(billId: billId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  final String billId;

  const _PaymentsTab({required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(billPaymentsProvider(billId));

    return paymentsAsync.when(
      loading: () => const KShimmerList(itemCount: 3),
      error: (err, _) => KErrorView(
        message: 'Failed to load payments',
        onRetry: () => ref.invalidate(billPaymentsProvider(billId)),
      ),
      data: (data) {
        final content = data['data'];
        final payments = (content is List)
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

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
            final payment = payments[index] as Map<String, dynamic>;
            final amount =
                (payment['amount'] as num?)?.toDouble() ?? 0;
            final paymentDate = payment['paymentDate'] as String?;
            final paymentMethod =
                payment['paymentMethod'] as String? ?? '--';
            final paymentNumber =
                payment['paymentNumber'] as String? ?? '--';

            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: KColors.success.withValues(alpha: 0.1),
                      borderRadius: KSpacing.borderRadiusMd,
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: KColors.success,
                      size: 20,
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paymentNumber,
                            style: KTypography.labelLarge),
                        Text(
                          '${paymentMethod.replaceAll('_', ' ')}${paymentDate != null ? ' · ${DateFormatter.display(DateTime.parse(paymentDate))}' : ''}',
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
}
