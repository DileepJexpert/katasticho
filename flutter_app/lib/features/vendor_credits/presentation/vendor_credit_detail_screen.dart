import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/vendor_credit_dto.dart';
import '../data/vendor_credit_providers.dart';
import '../data/vendor_credit_repository.dart';
import 'widgets/apply_to_bill_bottom_sheet.dart';

class VendorCreditDetailScreen extends ConsumerWidget {
  final String creditId;

  const VendorCreditDetailScreen({super.key, required this.creditId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(vendorCreditDetailProvider(creditId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Credit'),
        actions: [
          creditAsync.whenOrNull(
                data: (data) {
                  final credit =
                      (data['data'] ?? data) as Map<String, dynamic>;
                  final c = VendorCreditDto(credit);
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value, c),
                    itemBuilder: (context) => [
                      if (c.isDraft)
                        const PopupMenuItem(
                            value: 'post', child: Text('Post Credit')),
                      if (c.isDraft)
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Credit',
                                style: TextStyle(color: KColors.error))),
                      if (c.isOpen)
                        const PopupMenuItem(
                            value: 'void',
                            child: Text('Void Credit',
                                style: TextStyle(color: KColors.error))),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: creditAsync.when(
        loading: () => const KLoading(message: 'Loading credit...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load vendor credit',
          onRetry: () =>
              ref.invalidate(vendorCreditDetailProvider(creditId)),
        ),
        data: (data) {
          final credit =
              (data['data'] ?? data) as Map<String, dynamic>;
          return _CreditDetailBody(credit: credit, creditId: creditId);
        },
      ),
      bottomNavigationBar: creditAsync.whenOrNull(
        data: (data) {
          final credit =
              (data['data'] ?? data) as Map<String, dynamic>;
          final c = VendorCreditDto(credit);

          if (c.canApply) {
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
                        Text('Balance', style: KTypography.bodySmall),
                        Text(
                          CurrencyFormatter.formatIndian(c.balance),
                          style: KTypography.amountLarge.copyWith(
                            color: KColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    KButton(
                      label: 'Apply to Bill',
                      icon: Icons.assignment_return,
                      variant: KButtonVariant.secondary,
                      onPressed: () =>
                          showApplyToBillSheet(context, ref, credit),
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

  void _handleAction(BuildContext context, WidgetRef ref, String action,
      VendorCreditDto c) async {
    final repo = ref.read(vendorCreditRepositoryProvider);

    switch (action) {
      case 'post':
        try {
          await repo.postCredit(creditId);
          ref.invalidate(vendorCreditDetailProvider(creditId));
          ref.invalidate(vendorCreditListProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Credit posted — journal entry created')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to post credit')),
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
        title: const Text('Delete Credit?'),
        content: const Text(
          'This will permanently delete this draft vendor credit. This action cannot be undone.',
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
                final repo = ref.read(vendorCreditRepositoryProvider);
                await repo.deleteCredit(creditId);
                ref.invalidate(vendorCreditListProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Credit deleted')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to delete credit')),
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
        title: const Text('Void Credit?'),
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
                hintText: 'Why is this credit being voided?',
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
                final repo = ref.read(vendorCreditRepositoryProvider);
                final reason = reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim();
                await repo.voidCredit(creditId, reason: reason);
                ref.invalidate(vendorCreditDetailProvider(creditId));
                ref.invalidate(vendorCreditListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Credit voided')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to void credit')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Void Credit'),
          ),
        ],
      ),
    );
  }
}

class _CreditDetailBody extends StatelessWidget {
  final Map<String, dynamic> credit;
  final String creditId;

  const _CreditDetailBody(
      {required this.credit, required this.creditId});

  @override
  Widget build(BuildContext context) {
    final c = VendorCreditDto(credit);

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
                      child:
                          Text(c.creditNumber, style: KTypography.h2),
                    ),
                    KStatusChip(status: c.status),
                  ],
                ),
                KSpacing.vGapSm,
                Text(c.vendorName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(c.totalAmount),
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
                            label: 'Credit Number',
                            value: c.creditNumber),
                        KDetailRow(
                            label: 'Vendor', value: c.vendorName),
                        KDetailRow(
                          label: 'Credit Date',
                          value: c.creditDate.isEmpty
                              ? '--'
                              : c.creditDate,
                        ),
                        if (c.reason.isNotEmpty)
                          KDetailRow(label: 'Reason', value: c.reason),
                        if (c.placeOfSupply.isNotEmpty)
                          KDetailRow(
                              label: 'Place of Supply',
                              value: c.placeOfSupply),
                        KDetailRow(
                            label: 'Currency', value: c.currency),
                        const Divider(),
                        KDetailRow(
                          label: 'Subtotal',
                          value: CurrencyFormatter.formatIndian(
                              c.subtotal),
                        ),
                        KDetailRow(
                          label: 'Tax',
                          value: CurrencyFormatter.formatIndian(
                              c.taxAmount),
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Total',
                          value: CurrencyFormatter.formatIndian(
                              c.totalAmount),
                          valueStyle: KTypography.amountMedium,
                        ),
                        KDetailRow(
                          label: 'Balance',
                          value: CurrencyFormatter.formatIndian(
                              c.balance),
                          valueStyle: KTypography.amountSmall.copyWith(
                            color: c.balance > 0
                                ? KColors.primary
                                : KColors.success,
                          ),
                        ),
                        if (c.journalEntryId != null) ...[
                          const Divider(),
                          KDetailRow(
                              label: 'Journal Entry',
                              value: c.journalEntryId!),
                        ],
                      ],
                    ),
                  ),
                ),

                // Lines tab
                _LinesTab(lines: c.lines),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinesTab extends StatelessWidget {
  final List<CreditLineDto> lines;

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
                        Text(
                          line.description.isNotEmpty
                              ? line.description
                              : 'Line ${line.lineNumber}',
                          style: KTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (line.hsnCode.isNotEmpty)
                          Text(
                            'HSN: ${line.hsnCode}',
                            style: KTypography.bodySmall.copyWith(
                              color: KColors.textSecondary,
                            ),
                          ),
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
                  if (line.gstRate > 0) ...[
                    KSpacing.hGapSm,
                    Text(
                      'GST ${line.gstRate.toStringAsFixed(0)}%',
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
