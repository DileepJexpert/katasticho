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
import '../data/bill_dto.dart';
import '../data/bill_providers.dart';
import '../data/bill_repository.dart';
import 'widgets/bill_status_chip.dart';
import 'widgets/record_payment_bottom_sheet.dart';

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
                  final b = BillDto(bill);
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value, b),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'share',
                          child: Text('Share via WhatsApp')),
                      if (b.isDraft)
                        const PopupMenuItem(
                            value: 'post', child: Text('Post Bill')),
                      if (b.isDraft)
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Bill',
                                style: TextStyle(color: KColors.error))),
                      if (b.isPayable)
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
          final b = BillDto(bill);

          if (b.isPayable) {
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
                          CurrencyFormatter.formatIndian(b.balanceDue),
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
                          showRecordPaymentSheet(context, ref, bill),
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
      BuildContext context, WidgetRef ref, String action, BillDto b) async {
    final repo = ref.read(billRepositoryProvider);

    switch (action) {
      case 'share':
        if (context.mounted) {
          final api = ref.read(apiClientProvider);
          launchWhatsAppShare(
            context,
            fetchShareData: () => api.get(
              ApiConfig.billWhatsAppLink(billId),
            ).then((r) => r.data as Map<String, dynamic>),
          );
        }
        break;
      case 'post':
        try {
          await repo.postBill(billId);
          ref.invalidate(billDetailProvider(billId));
          ref.invalidate(billListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Bill posted — journal entry created')),
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
                  context.go('/bills');
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
}

class _BillDetailBody extends ConsumerWidget {
  final Map<String, dynamic> bill;
  final String billId;

  const _BillDetailBody({required this.bill, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = BillDto(bill);

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
                      child: Text(b.billNumber, style: KTypography.h2),
                    ),
                    BillStatusChip(status: b.status),
                  ],
                ),
                KSpacing.vGapSm,
                Text(b.vendorName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(b.totalAmount),
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
                            label: 'Bill Number', value: b.billNumber),
                        KDetailRow(label: 'Vendor', value: b.vendorName),
                        KDetailRow(
                          label: 'Vendor Bill #',
                          value: b.vendorBillNumber.isEmpty
                              ? '--'
                              : b.vendorBillNumber,
                        ),
                        KDetailRow(
                          label: 'Bill Date',
                          value: b.billDate.isEmpty ? '--' : b.billDate,
                        ),
                        KDetailRow(
                          label: 'Due Date',
                          value: b.dueDate.isEmpty ? '--' : b.dueDate,
                        ),
                        KDetailRow(
                          label: 'Place of Supply',
                          value: b.placeOfSupply.isEmpty
                              ? '--'
                              : b.placeOfSupply,
                        ),
                        if (b.reverseCharge)
                          const KDetailRow(
                              label: 'Reverse Charge', value: 'Yes'),
                        const Divider(),
                        KDetailRow(
                          label: 'Subtotal',
                          value: CurrencyFormatter.formatIndian(b.subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          value: CurrencyFormatter.formatIndian(b.taxAmount),
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Total',
                          value:
                              CurrencyFormatter.formatIndian(b.totalAmount),
                          valueStyle: KTypography.amountMedium,
                        ),
                        KDetailRow(
                          label: 'Amount Paid',
                          value:
                              CurrencyFormatter.formatIndian(b.amountPaid),
                          valueStyle: KTypography.amountSmall.copyWith(
                            color: KColors.success,
                          ),
                        ),
                        if (b.notes.isNotEmpty) ...[
                          const Divider(),
                          KDetailRow(label: 'Notes', value: b.notes),
                        ],
                      ],
                    ),
                  ),
                ),

                // Lines tab
                _LinesTab(lines: b.lines),

                // Payments tab
                _PaymentsTab(billId: billId),

                // Activity tab
                KActivityTimeline(
                  entityType: 'BILL',
                  entityId: billId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinesTab extends StatelessWidget {
  final List<BillLineDto> lines;

  const _LinesTab({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const KEmptyState(
        icon: Icons.list_alt,
        title: 'No line items',
      );
    }

    return ListView.builder(
      padding: KSpacing.pagePadding,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        return KCard(
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.itemName,
                            style: KTypography.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600)),
                        if (line.description.isNotEmpty)
                          Text(line.description,
                              style: KTypography.bodySmall.copyWith(
                                  color: KColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(line.lineTotal),
                    style: KTypography.amountSmall,
                  ),
                ],
              ),
              KSpacing.vGapXs,
              Row(
                children: [
                  Text(
                    '${line.quantity.toStringAsFixed(line.quantity.truncateToDouble() == line.quantity ? 0 : 2)} x ${CurrencyFormatter.formatIndian(line.unitPrice)}',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                  if (line.taxGroupName != null) ...[
                    KSpacing.hGapSm,
                    Text(
                      line.taxGroupName!,
                      style: KTypography.labelSmall.copyWith(
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
            final payment = BillPaymentDto(
                payments[index] as Map<String, dynamic>);

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
                        Text(payment.paymentNumber,
                            style: KTypography.labelLarge),
                        Text(
                          '${payment.paymentMethod.replaceAll('_', ' ')}${payment.paymentDate.isNotEmpty ? ' · ${DateFormatter.display(DateTime.parse(payment.paymentDate))}' : ''}',
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(payment.amount),
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
